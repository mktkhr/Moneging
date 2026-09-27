import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import {
  evaluate,
  localDateString,
  parseUnlockDate,
  readGitRefFile,
  readLockState,
} from "./harness-lock.ts";

describe("parseUnlockDate", () => {
  it("reads the date named by a valid line", () => {
    assert.equal(parseUnlockDate("unlocked-until: 2026-10-31\n"), "2026-10-31");
  });

  it("skips leading comments and blank lines", () => {
    assert.equal(parseUnlockDate("# comment\n\nunlocked-until: 2026-10-31\n"), "2026-10-31");
  });

  it("returns null for a missing key", () => {
    assert.equal(parseUnlockDate("unlocked-until:\n"), null);
  });

  it("returns null for a calendar date that does not exist", () => {
    assert.equal(parseUnlockDate("unlocked-until: 2026-13-40\n"), null);
  });

  it("returns null for garbage content", () => {
    assert.equal(parseUnlockDate("nonsense\n"), null);
    assert.equal(parseUnlockDate(""), null);
  });
});

describe("localDateString", () => {
  it("formats a date as zero-padded YYYY-MM-DD", () => {
    assert.equal(localDateString(new Date(2026, 0, 5)), "2026-01-05");
    assert.equal(localDateString(new Date(2026, 9, 31)), "2026-10-31");
  });
});

describe("evaluate", () => {
  it("is unlocked when today is on or before the named date", () => {
    assert.deepEqual(evaluate("unlocked-until: 2026-10-31\n", "2026-10-31"), {
      unlocked: true,
      until: "2026-10-31",
      reason: "unlocked",
    });
    assert.equal(evaluate("unlocked-until: 2026-10-31\n", "2026-01-01").unlocked, true);
  });

  it("is locked once today is after the named date", () => {
    assert.deepEqual(evaluate("unlocked-until: 2026-10-31\n", "2026-11-01"), {
      unlocked: false,
      until: "2026-10-31",
      reason: "expired",
    });
  });

  it("is locked, fail closed, when the file is missing", () => {
    assert.deepEqual(evaluate(null, "2026-01-01"), {
      unlocked: false,
      until: null,
      reason: "missing",
    });
  });

  it("is locked, fail closed, when the content does not parse", () => {
    assert.deepEqual(evaluate("nonsense\n", "2026-01-01"), {
      unlocked: false,
      until: null,
      reason: "malformed",
    });
  });
});

// readLockState against an injected reader: fast, no real git repository.
// This is what governs the actual decision (the argument order and the
// exact ref/path readLockState asks for), independent of readGitRefFile's
// own plumbing, which the "real git repository" suite below exercises.
describe("readLockState with an injected reader", () => {
  it("asks the reader for refs/harness/approved:quality/harness-lock.txt", () => {
    const calls: [string, string, string][] = [];
    const reader = (root: string, ref: string, filePath: string): string | null => {
      calls.push([root, ref, filePath]);

      return "unlocked-until: 2099-01-01\n";
    };

    const state = readLockState("/repo", "2026-01-01", reader);

    assert.deepEqual(calls, [["/repo", "refs/harness/approved", "quality/harness-lock.txt"]]);
    assert.equal(state.unlocked, true);
  });

  it("is locked when the reader reports the ref or file as absent (returns null)", () => {
    const state = readLockState("/repo", "2026-01-01", () => null);

    assert.deepEqual(state, { unlocked: false, until: null, reason: "missing" });
  });

  it("is locked once today is after the date the reader reports", () => {
    const reader = (): string | null => "unlocked-until: 2020-01-01\n";
    const state = readLockState("/repo", "2026-01-01", reader);

    assert.deepEqual(state, { unlocked: false, until: "2020-01-01", reason: "expired" });
  });
});

// readGitRefFile and readLockState (default reader) against a real,
// throwaway git repository, so the actual `git show <ref>:<path>` plumbing
// is exercised, not just the pure decision logic above.
describe("readLockState against a real temporary git repository", () => {
  function makeRepo(): string {
    const root = mkdtempSync(path.join(tmpdir(), "harness-lock-repo-"));

    execFileSync("git", ["init", "-q"], { cwd: root });
    execFileSync("git", ["config", "user.email", "test@example.com"], { cwd: root });
    execFileSync("git", ["config", "user.name", "test"], { cwd: root });

    return root;
  }

  it("is locked, fail closed, when refs/harness/approved does not exist yet", () => {
    const root = makeRepo();

    try {
      writeFileSync(path.join(root, "README.md"), "x\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "init"], { cwd: root });

      // No refs/harness/approved was ever created: a fresh clone before the
      // first `make hooks`/`make harness-approve`, or this repo's own state
      // before that ref exists.
      const state = readLockState(root, "2026-01-01");

      assert.deepEqual(state, { unlocked: false, until: null, reason: "missing" });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("is locked when the approved ref exists but has no quality/harness-lock.txt", () => {
    const root = makeRepo();

    try {
      writeFileSync(path.join(root, "README.md"), "x\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "init"], { cwd: root });
      execFileSync("git", ["update-ref", "refs/harness/approved", "HEAD"], { cwd: root });

      const state = readLockState(root, "2026-01-01");

      assert.deepEqual(state, { unlocked: false, until: null, reason: "missing" });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("is unlocked when the approved commit's harness-lock.txt names a future date", () => {
    const root = makeRepo();

    try {
      execFileSync("mkdir", ["-p", path.join(root, "quality")]);
      writeFileSync(path.join(root, "quality", "harness-lock.txt"), "unlocked-until: 2099-01-01\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "unlock"], { cwd: root });
      execFileSync("git", ["update-ref", "refs/harness/approved", "HEAD"], { cwd: root });

      const state = readLockState(root, "2026-01-01");

      assert.deepEqual(state, { unlocked: true, until: "2099-01-01", reason: "unlocked" });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("is locked once today passes the approved commit's date", () => {
    const root = makeRepo();

    try {
      execFileSync("mkdir", ["-p", path.join(root, "quality")]);
      writeFileSync(path.join(root, "quality", "harness-lock.txt"), "unlocked-until: 2020-01-01\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "unlock, now expired"], { cwd: root });
      execFileSync("git", ["update-ref", "refs/harness/approved", "HEAD"], { cwd: root });

      const state = readLockState(root, "2026-01-01");

      assert.deepEqual(state, { unlocked: false, until: "2020-01-01", reason: "expired" });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("ignores a malformed committed file at the approved ref (fail closed)", () => {
    const root = makeRepo();

    try {
      execFileSync("mkdir", ["-p", path.join(root, "quality")]);
      writeFileSync(path.join(root, "quality", "harness-lock.txt"), "nonsense\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "malformed"], { cwd: root });
      execFileSync("git", ["update-ref", "refs/harness/approved", "HEAD"], { cwd: root });

      const state = readLockState(root, "2026-01-01");

      assert.deepEqual(state, { unlocked: false, until: null, reason: "malformed" });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  // The behaviour change this fix exists for: a working-tree edit to
  // quality/harness-lock.txt, uncommitted or committed-but-not-approved, has
  // no effect on the lock state until `make harness-approve` moves the ref.
  it("ignores an uncommitted working-tree edit and keeps reading the approved commit", () => {
    const root = makeRepo();

    try {
      execFileSync("mkdir", ["-p", path.join(root, "quality")]);
      writeFileSync(path.join(root, "quality", "harness-lock.txt"), "unlocked-until: 2099-01-01\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "approved: unlocked far in the future"], {
        cwd: root,
      });
      execFileSync("git", ["update-ref", "refs/harness/approved", "HEAD"], { cwd: root });

      // Simulate a session editing the working tree, or a human editing it
      // and not yet committing/approving: the file now says LOCKED, and is
      // not even valid.
      writeFileSync(path.join(root, "quality", "harness-lock.txt"), "unlocked-until: 2020-01-01\n");

      const state = readLockState(root, "2026-01-01");

      // Still reads the approved commit's 2099 date, not the dirty 2020 one.
      assert.deepEqual(state, { unlocked: true, until: "2099-01-01", reason: "unlocked" });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("ignores a later commit that was never approved", () => {
    const root = makeRepo();

    try {
      execFileSync("mkdir", ["-p", path.join(root, "quality")]);
      writeFileSync(path.join(root, "quality", "harness-lock.txt"), "unlocked-until: 2099-01-01\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "approved: unlocked"], { cwd: root });
      execFileSync("git", ["update-ref", "refs/harness/approved", "HEAD"], { cwd: root });

      // A further commit lands on the branch (e.g. by a session that
      // shouldn't have been able to write this file at all, or by a human
      // who has not yet run `make harness-approve`); refs/harness/approved
      // still points at the earlier commit.
      writeFileSync(path.join(root, "quality", "harness-lock.txt"), "unlocked-until: 2020-01-01\n");
      execFileSync("git", ["add", "-A"], { cwd: root });
      execFileSync("git", ["commit", "-q", "-m", "not approved"], { cwd: root });

      const state = readLockState(root, "2026-01-01");

      assert.deepEqual(state, { unlocked: true, until: "2099-01-01", reason: "unlocked" });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("readGitRefFile itself returns null, not a throw, when git or the repo is unusable", () => {
    const notARepo = mkdtempSync(path.join(tmpdir(), "harness-lock-notrepo-"));

    try {
      assert.equal(readGitRefFile(notARepo, "refs/harness/approved", "quality/harness-lock.txt"), null);
    } finally {
      rmSync(notARepo, { recursive: true, force: true });
    }
  });
});

// The CLI's root argument (protected-paths.sh passes its own resolved
// toplevel) takes precedence over $CLAUDE_PROJECT_DIR, which may point
// somewhere else or not be set at all outside a Claude Code session.
describe("CLI: root argument takes precedence over CLAUDE_PROJECT_DIR", () => {
  function makeApprovedRepo(untilDate: string): string {
    const root = mkdtempSync(path.join(tmpdir(), "harness-lock-cli-"));

    execFileSync("git", ["init", "-q"], { cwd: root });
    execFileSync("git", ["config", "user.email", "test@example.com"], { cwd: root });
    execFileSync("git", ["config", "user.name", "test"], { cwd: root });
    execFileSync("mkdir", ["-p", path.join(root, "quality")]);
    writeFileSync(path.join(root, "quality", "harness-lock.txt"), `unlocked-until: ${untilDate}\n`);
    execFileSync("git", ["add", "-A"], { cwd: root });
    execFileSync("git", ["commit", "-q", "-m", "approved"], { cwd: root });
    execFileSync("git", ["update-ref", "refs/harness/approved", "HEAD"], { cwd: root });

    return root;
  }

  it("reads the argv root's state, not the CLAUDE_PROJECT_DIR env root's", () => {
    const argRoot = makeApprovedRepo("2099-01-01"); // unlocked
    const envRoot = makeApprovedRepo("2020-01-01"); // locked (expired)

    try {
      const cliPath = path.join(import.meta.dirname, "harness-lock.ts");
      const out = execFileSync("node", [cliPath, argRoot], {
        env: { ...process.env, CLAUDE_PROJECT_DIR: envRoot },
        encoding: "utf8",
      });

      assert.match(out, /^unlocked 2099-01-01\n$/u);
    } finally {
      rmSync(argRoot, { recursive: true, force: true });
      rmSync(envRoot, { recursive: true, force: true });
    }
  });

  it("falls back to CLAUDE_PROJECT_DIR when no argv root is given", () => {
    const envRoot = makeApprovedRepo("2099-01-01");

    try {
      const cliPath = path.join(import.meta.dirname, "harness-lock.ts");
      const out = execFileSync("node", [cliPath], {
        env: { ...process.env, CLAUDE_PROJECT_DIR: envRoot },
        encoding: "utf8",
      });

      assert.match(out, /^unlocked 2099-01-01\n$/u);
    } finally {
      rmSync(envRoot, { recursive: true, force: true });
    }
  });
});

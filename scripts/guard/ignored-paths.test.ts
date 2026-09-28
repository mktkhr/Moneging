// Regression coverage for scripts/guard/ignored-paths.sh against real,
// throwaway git repositories (the script is `sh`, not TypeScript - there is
// no pure logic to unit-test in isolation, so this drives the actual script
// as a subprocess against a minimal harness it recognises).
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

const SCRIPT = path.join(import.meta.dirname, "ignored-paths.sh");

const GOOD_GITIGNORE = `*

!.gitignore
!hooks/
!hooks/**
!quality/
!quality/**
!.claude/
!.claude/settings.json
`;

function write(root: string, relative: string, content: string): void {
  const full = path.join(root, relative);

  mkdirSync(path.dirname(full), { recursive: true });
  writeFileSync(full, content);
}

/** A minimal repository with the harness shape ignored-paths.sh expects: a registry naming a few real directories, each with tracked source under it. */
function makeRepo(): string {
  const root = mkdtempSync(path.join(tmpdir(), "ignored-paths-repo-"));

  execFileSync("git", ["init", "-q"], { cwd: root });
  execFileSync("git", ["config", "user.email", "test@example.com"], { cwd: root });
  execFileSync("git", ["config", "user.name", "test"], { cwd: root });

  write(root, ".gitignore", GOOD_GITIGNORE);
  write(root, "quality/protected-paths.txt", "quality\nhooks\n.claude\n");
  write(root, "hooks/commit-msg", "#!/bin/sh\n");
  write(root, "hooks/pre-commit", "#!/bin/sh\n");
  write(root, ".claude/settings.json", "{}\n");

  execFileSync("git", ["add", "-A"], { cwd: root });
  execFileSync("git", ["commit", "-q", "-m", "init"], { cwd: root });

  return root;
}

function runGuard(root: string): { status: number | null; stdout: string; stderr: string } {
  const result = spawnSync("sh", [SCRIPT], { cwd: root, encoding: "utf8" });

  return { status: result.status, stdout: result.stdout, stderr: result.stderr };
}

describe("ignored-paths.sh", () => {
  it("passes when every allow line is intact", () => {
    const root = makeRepo();

    try {
      const result = runGuard(root);

      assert.equal(result.status, 0);
      assert.match(result.stdout, /no protected path is ignored/u);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  // The exact case the literal takamai port false-passed: `!hooks/` alone
  // still un-ignores the bare directory, and `git check-ignore` skips
  // already-tracked files by default, so this hole only shows up by checking
  // the actual tracked files under the directory (see the file-level comment
  // in ignored-paths.sh).
  it("fails when !hooks/** is removed, even though hooks/ itself stays tracked", () => {
    const root = makeRepo();

    try {
      write(root, ".gitignore", GOOD_GITIGNORE.replace("!hooks/**\n", ""));

      const result = runGuard(root);

      assert.equal(result.status, 1);
      assert.match(result.stdout, /hooks\/commit-msg/u);
      assert.match(result.stdout, /hooks\/pre-commit/u);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("passes again once the allow line is restored", () => {
    const root = makeRepo();

    try {
      write(root, ".gitignore", GOOD_GITIGNORE.replace("!hooks/**\n", ""));
      assert.equal(runGuard(root).status, 1);

      write(root, ".gitignore", GOOD_GITIGNORE);

      assert.equal(runGuard(root).status, 0);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  // .claude/worktrees/ is Claude Code's own worktree checkouts: untracked,
  // always ignored (nothing under .claude/ is allow-listed but
  // settings.json), and never a gate going dark.
  it("does not flag ignored, untracked files under .claude/worktrees/", () => {
    const root = makeRepo();

    try {
      write(root, ".claude/worktrees/some-branch/a.ts", "x\n");

      const result = runGuard(root);

      assert.equal(result.status, 0);
      assert.match(result.stdout, /no protected path is ignored/u);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  // A build/cache artifact under a protected directory is allowed to be
  // ignored - only its sources are not.
  it("does not flag a non-source, ignored build artifact under a protected directory", () => {
    const root = makeRepo();

    try {
      write(root, ".gitignore", `${GOOD_GITIGNORE}quality/out/\n`);
      write(root, "quality/out/data.bin", "binary\n");

      const result = runGuard(root);

      assert.equal(result.status, 0);
      assert.match(result.stdout, /no protected path is ignored/u);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("does flag a source file swallowed by a fresh ignore rule under a protected directory", () => {
    const root = makeRepo();

    try {
      write(root, ".gitignore", `${GOOD_GITIGNORE}quality/out/\n`);
      write(root, "quality/out/build.json", "{}\n");

      const result = runGuard(root);

      assert.equal(result.status, 1);
      assert.match(result.stdout, /quality\/out\/build\.json/u);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});

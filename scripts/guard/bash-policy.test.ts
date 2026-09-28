// Ported from takamai's scripts/guard/bash-policy.test.ts: node:test + node:assert
// instead of vite-plus/test (zero npm dependencies here), Moneging commands/paths
// instead of Go/web ones, and role coverage (scripts/guard/roles.ts) this
// repository adds. Dropped: the node_modules-edit rule (no npm dependencies here)
// and the `gh ... label` rule (no CI label gate here). Added: git add -f/--force,
// and the commit backstop for restricted roles.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { type ChangeLister, bannedCommand, listChangedPaths } from "./bash-policy.ts";
import { protectedEntries } from "./protected-entries.ts";
import type { Role } from "./roles.ts";

const entries = protectedEntries(
  "# comment\nquality\nhooks\nMakefile\n.claude\nCLAUDE.md\nscripts/guard\nPRODUCT.md\nacceptance\n",
);
const root = "/repo";
const ROLES: readonly Role[] = ["main", "restricted", "acceptance-writer", "reviewer"];

/** A lister reporting a fixed set of staged paths, so tests never run git. */
function staged(...files: string[]): ChangeLister {
  return () => files;
}

const nothingStaged = staged();

function banned(command: string, role: Role, cwd?: string, lister = nothingStaged): string | null {
  return bannedCommand(command, entries, root, cwd, role, lister);
}

describe("bannedCommand: refused to every role", () => {
  for (const command of [
    "git commit --no-verify -m 'x'",
    "git commit -nm 'x'",
    "git config core.hooksPath /dev/null",
    "git -c core.hooksPath=/dev/null commit -m x",
    "git push --force origin main",
    "git push -f",
    "git push --force-with-lease",
    "git add -f docs/superpowers/x.md",
    "git add --force .",
    "git apply fix.diff",
    "git am < x.mbox",
    "patch -p1 < fix.diff",
    "echo x > .cache/stop-gate/verified",
    "git update-index --assume-unchanged Makefile",
    "git update-index --skip-worktree Makefile",
    "git config --unset core.hookspath",
    "git commit --no-verif -m x",
    "git commit --no-ver -m x",
    "git push origin +main",
    "echo x > .git/config",
    "echo x > .claude/settings.local.json",
  ]) {
    for (const role of ROLES) {
      it(`refuses ${command} (${role})`, () => {
        assert.notEqual(banned(command, role), null);
      });
    }
  }
});

describe("bannedCommand: allowed to a restricted subagent", () => {
  for (const command of [
    "make check",
    "git commit -m 'feat(sharedLogic): add money type'",
    "cat quality/commit-types.txt",
    "git push origin agent/stage-1",
    'git commit -m "fix the patch parser"',
    "make verify",
    "git add .",
    "git add docs/handbook/x.md",
  ]) {
    it(`allows ${command}`, () => {
      assert.equal(banned(command, "restricted"), null);
    });
  }
});

describe("bannedCommand: harness paths by role", () => {
  for (const command of [
    "echo x > quality/commit-types.txt",
    "echo x > CLAUDE.md",
    "rm -rf quality",
    "git checkout -- Makefile",
    "perl -pi -e 's/a/b/' Makefile",
    "install -m644 x quality/y",
    "dd of=quality/z if=/dev/null",
  ]) {
    it(`refuses ${command} to a restricted subagent, the acceptance writer and the reviewer`, () => {
      assert.notEqual(banned(command, "restricted"), null);
      assert.notEqual(banned(command, "acceptance-writer"), null);
      assert.notEqual(banned(command, "reviewer"), null);
    });

    it(`allows ${command} to the main session`, () => {
      assert.equal(banned(command, "main"), null);
    });
  }

  it("defaults to the restricted role when omitted", () => {
    assert.notEqual(bannedCommand("echo x > CLAUDE.md", entries, root), null);
  });
});

describe("bannedCommand: acceptance/ and product code by role", () => {
  it("refuses acceptance/ to a restricted subagent, allows it to the acceptance writer", () => {
    assert.notEqual(banned("echo x > acceptance/shared/A.kt", "restricted"), null);
    assert.equal(banned("echo x > acceptance/shared/A.kt", "acceptance-writer"), null);
  });

  it("refuses everything outside acceptance/ to the acceptance writer", () => {
    assert.notEqual(banned("echo x > docs/handbook/x.md", "acceptance-writer"), null);
    assert.notEqual(banned("echo x > PRODUCT.md", "acceptance-writer"), null);
    assert.equal(banned("echo x > /tmp/scratch.txt", "acceptance-writer"), null);
  });

  it("refuses PRODUCT.md to a restricted subagent", () => {
    assert.notEqual(banned("echo x >> PRODUCT.md", "restricted"), null);
  });

  it("refuses product code to the acceptance writer, allows it to a restricted subagent", () => {
    assert.notEqual(banned("echo x > clients/kmp/Money.kt", "acceptance-writer"), null);
    assert.equal(banned("echo x > clients/kmp/Money.kt", "restricted"), null);
  });

  it("refuses any repository write to the reviewer, allows writes outside it", () => {
    assert.notEqual(banned("echo x > clients/kmp/Money.kt", "reviewer"), null);
    assert.equal(banned("make check > /tmp/out.log 2>&1", "reviewer"), null);
  });
});

describe("bannedCommand: commit backstop", () => {
  it("refuses a restricted commit that stages a harness or acceptance path", () => {
    assert.notEqual(banned("git commit -m x", "restricted", undefined, staged("quality/x")), null);
    assert.notEqual(
      banned("git commit -m x", "restricted", undefined, staged("clients/a.kt", "acceptance/b.kt")),
      null,
    );
  });

  it("allows a restricted commit of product code only", () => {
    assert.equal(banned("git commit -m x", "restricted", undefined, staged("clients/a.kt")), null);
  });


  it("refuses an acceptance writer commit that stages product code", () => {
    assert.notEqual(
      banned("git commit -m x", "acceptance-writer", undefined, staged("clients/a.kt")),
      null,
    );
    assert.equal(
      banned("git commit -m x", "acceptance-writer", undefined, staged("acceptance/a.kt")),
      null,
    );
  });

  it("refuses every commit by the reviewer", () => {
    assert.notEqual(banned("git commit -m x", "reviewer"), null);
  });

  it("does not restrict the main session's commits", () => {
    assert.equal(banned("git commit -m x", "main", undefined, staged("quality/x", "acceptance/a")), null);
  });
});

describe("bannedCommand reads redirects, not every token, as writes", () => {
  for (const command of [
    "cd clients/kmp && ./gradlew test 2>&1 | tail",
    "grep -rn X quality/ 2>/dev/null",
    "cat CLAUDE.md 2>&1",
    "git diff Makefile 2>&1",
    "make check > /tmp/out.log 2>&1",
  ]) {
    it(`allows ${command}`, () => {
      assert.equal(banned(command, "restricted"), null);
    });
  }

  for (const command of [
    "echo x > quality/y",
    "cat > quality/x <<EOF",
    "echo x >> CLAUDE.md",
    "echo x &> Makefile",
  ]) {
    it(`refuses ${command} to a restricted subagent`, () => {
      assert.notEqual(banned(command, "restricted"), null);
    });
  }

  it("refuses a write resolved against the tool call's cwd", () => {
    assert.notEqual(banned("sed -i s/a/b/ x_test.kt", "restricted", "scripts/guard"), null);
  });
});

describe("bannedCommand allows read-only commands about the harness", () => {
  for (const command of ["cat .cache/stop-gate/failing", "git log --oneline"]) {
    it(`allows ${command}`, () => {
      assert.equal(banned(command, "restricted"), null);
    });
  }

  it("refuses rm .cache/stop-gate/judged", () => {
    assert.notEqual(banned("rm .cache/stop-gate/judged", "main"), null);
  });
});

describe("bannedCommand skips the verb when scanning tokens as paths", () => {
  it("allows a write outside the protected cwd", () => {
    assert.equal(banned("rm /tmp/foo", "restricted", "scripts/guard"), null);
  });

  it("refuses a write resolved into the protected cwd", () => {
    assert.notEqual(banned("rm x_test.ts", "restricted", "scripts/guard"), null);
  });

  it("refuses a write reaching a protected path above the cwd", () => {
    assert.notEqual(banned("sed -i s/a/b/ ../../quality/x", "restricted", "scripts/guard/archcheck"), null);
  });
});

describe("bannedCommand: commit-producing commands and destructive git for subagents", () => {
  for (const command of ["git cherry-pick abc", "git revert HEAD", "git merge x", "git -C . commit -m x", "git pull"]) {
    it(`checks ${command} against the working tree`, () => {
      assert.notEqual(banned(command, "restricted", undefined, staged("quality/x")), null);
      assert.equal(banned(command, "restricted", undefined, staged("clients/a.kt")), null);
    });
  }

  it("does not treat a log format string as a commit", () => {
    assert.equal(banned("git log --pretty='commit %H'", "reviewer"), null);
  });

  for (const command of ["git reset --hard", "git clean -fdx", "git stash", "git checkout .", "git restore -- ."]) {
    it(`refuses ${command} to subagents, allows it to main`, () => {
      assert.notEqual(banned(command, "restricted"), null);
      assert.notEqual(banned(command, "reviewer"), null);
      assert.equal(banned(command, "main"), null);
    });
  }
});

describe("bannedCommand: cd and directory variables", () => {
  it("resolves writes after a cd against the new directory", () => {
    assert.notEqual(banned("cd quality && echo hi > x.txt", "restricted"), null);
    assert.equal(banned("cd clients && echo hi > x.txt", "restricted"), null);
  });

  it("expands $PWD and $CLAUDE_PROJECT_DIR", () => {
    assert.notEqual(banned("echo x > $PWD/quality/x", "restricted"), null);
    assert.notEqual(banned("echo x > ${CLAUDE_PROJECT_DIR}/CLAUDE.md", "restricted"), null);
  });
});

describe("listChangedPaths against a real git repository", () => {
  function repo(): string {
    const dir = mkdtempSync(path.join(tmpdir(), "bash-policy-"));
    const git = (...args: string[]): void => {
      execFileSync("git", args, { cwd: dir, stdio: "ignore" });
    };

    git("init", "-q");
    git("config", "user.email", "t@example.com");
    git("config", "user.name", "t");
    mkdirSync(path.join(dir, "quality"));
    writeFileSync(path.join(dir, "quality", "protected-paths.txt"), "quality\n");
    git("add", ".");
    git("commit", "-q", "-m", "init");

    return dir;
  }

  it("lists both sides of a staged rename", () => {
    const dir = repo();

    try {
      mkdirSync(path.join(dir, "docs"));
      execFileSync("git", ["mv", "quality/protected-paths.txt", "docs/pp.txt"], { cwd: dir });
      const files = listChangedPaths(dir);

      assert.ok(files.includes("quality/protected-paths.txt"));
      assert.ok(files.includes("docs/pp.txt"));
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("lists a non-ASCII name unquoted", () => {
    const dir = repo();

    try {
      writeFileSync(path.join(dir, "quality", "テスト.txt"), "x");
      assert.ok(listChangedPaths(dir).includes("quality/テスト.txt"));
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("lists unstaged and untracked changes, so add-then-commit in one command is caught", () => {
    const dir = repo();

    try {
      writeFileSync(path.join(dir, "quality", "protected-paths.txt"), "changed\n");
      writeFileSync(path.join(dir, "quality", "new.txt"), "x");
      const files = listChangedPaths(dir);

      assert.ok(files.includes("quality/protected-paths.txt"));
      assert.ok(files.includes("quality/new.txt"));
      assert.notEqual(
        bannedCommand("git add quality/new.txt && git commit -m x", ["quality"], dir, undefined, "restricted"),
        null,
      );
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

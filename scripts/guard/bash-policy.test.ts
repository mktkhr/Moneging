// Ported from takamai's scripts/guard/bash-policy.test.ts: node:test + node:assert
// instead of vite-plus/test (zero npm dependencies here), Moneging commands/paths
// instead of Go/web ones, and reviewer-role coverage this repository adds.
// Dropped: the node_modules-edit rule (no npm dependencies here) and the
// `gh ... label` rule (no CI label gate here). Added: git add -f/--force.
import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { bannedCommand } from "./bash-policy.ts";
import { protectedEntries } from "./protected-entries.ts";

const entries = protectedEntries(
  "# comment\nquality\nhooks\nMakefile\n.claude\nCLAUDE.md\nscripts/guard\n",
);
const root = "/repo";

describe("bannedCommand: refused always, reviewer or not", () => {
  for (const command of [
    "git commit --no-verify -m 'x'",
    "git commit -nm 'x'",
    "git config core.hooksPath /dev/null",
    "git -c core.hooksPath=/dev/null commit -m x",
    "MONEGING_ALLOW_HARNESS_CHANGE=1 git commit -m 'x'",
    "git push --force origin main",
    "git push -f",
    "git push --force-with-lease",
    "git add -f docs/superpowers/x.md",
    "git add --force .",
    "git apply fix.diff",
    "git am < x.mbox",
    "patch -p1 < fix.diff",
    "echo x > .cache/stop-gate/verified",
    "git update-ref refs/harness/approved HEAD",
    "git update-index --assume-unchanged Makefile",
    "git update-index --skip-worktree Makefile",
    "git config --unset core.hookspath",
    "git commit --no-verif -m x",
    "git commit --no-ver -m x",
    "git push origin +main",
  ]) {
    it(`refuses ${command}`, () => {
      assert.notEqual(bannedCommand(command, entries, root, undefined, true), null);
      assert.notEqual(bannedCommand(command, entries, root, undefined, false), null);
    });
  }

  it("refuses to write near .git or the local Claude settings", () => {
    assert.notEqual(bannedCommand("echo x > .git/config", entries, root, undefined, true), null);
    assert.notEqual(
      bannedCommand("echo x > .claude/settings.local.json", entries, root, undefined, true),
      null,
    );
  });
});

describe("bannedCommand: allowed", () => {
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
      assert.equal(bannedCommand(command, entries, root), null);
    });
  }
});

describe("bannedCommand: protected paths", () => {
  for (const command of [
    "echo x > quality/commit-types.txt",
    "echo x > CLAUDE.md",
    "rm -rf quality",
    "git checkout -- Makefile",
    "perl -pi -e 's/a/b/' Makefile",
    "install -m644 x quality/y",
    "dd of=quality/z if=/dev/null",
  ]) {
    it(`refuses ${command}`, () => {
      assert.notEqual(bannedCommand(command, entries, root, undefined, false), null);
    });
  }

  it("refuses the same with the flag omitted", () => {
    assert.notEqual(bannedCommand("echo x > CLAUDE.md", entries, root), null);
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
      assert.equal(bannedCommand(command, entries, root), null);
    });
  }

  for (const command of [
    "echo x > quality/y",
    "cat > quality/x <<EOF",
    "echo x >> CLAUDE.md",
    "echo x &> Makefile",
  ]) {
    it(`refuses ${command}`, () => {
      assert.notEqual(bannedCommand(command, entries, root, undefined, false), null);
    });
  }

  it("refuses a write resolved against the tool call's cwd", () => {
    assert.notEqual(
      bannedCommand("sed -i s/a/b/ x_test.kt", entries, root, "scripts/guard", false),
      null,
    );
  });
});

describe("bannedCommand allows read-only commands about the harness", () => {
  for (const command of [
    "cat .cache/stop-gate/failing",
    "grep -rn update-ref docs/",
    "git show-ref refs/harness/approved",
    "git log --oneline",
  ]) {
    it(`allows ${command}`, () => {
      assert.equal(bannedCommand(command, entries, root), null);
    });
  }

  for (const command of [
    "rm .cache/stop-gate/judged",
    "git update-ref refs/harness/approved HEAD",
    "git push . HEAD:refs/harness/approved",
  ]) {
    it(`refuses ${command}`, () => {
      assert.notEqual(bannedCommand(command, entries, root), null);
    });
  }
});

describe("bannedCommand: reviewer", () => {
  it("refuses a product-code write and any commit", () => {
    assert.notEqual(bannedCommand("echo x > clients/kmp/Money.kt", entries, root, undefined, true), null);
    assert.equal(bannedCommand("echo x > clients/kmp/Money.kt", entries, root, undefined, false), null);
    assert.notEqual(bannedCommand("git commit -m x", entries, root, undefined, true), null);
  });

  it("allows writes outside the repository", () => {
    assert.equal(bannedCommand("make check > /tmp/out.log 2>&1", entries, root, undefined, true), null);
  });
});

describe("bannedCommand skips the verb when scanning tokens as paths", () => {
  it("allows a write outside the protected cwd", () => {
    assert.equal(bannedCommand("rm /tmp/foo", entries, root, "scripts/guard", false), null);
  });

  it("refuses a write resolved into the protected cwd,", () => {
    assert.notEqual(bannedCommand("rm x_test.ts", entries, root, "scripts/guard", false), null);
  });

  it("refuses a write reaching a protected path above the cwd,", () => {
    assert.notEqual(
      bannedCommand("sed -i s/a/b/ ../../quality/x", entries, root, "scripts/guard/archcheck", false),
      null,
    );
  });
});

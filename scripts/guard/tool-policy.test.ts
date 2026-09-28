// Ported from takamai's scripts/guard/tool-policy.test.ts: node:test + node:assert
// instead of vite-plus/test (zero npm dependencies here), Moneging paths instead of
// Go/web ones, and reviewer-role coverage this repository adds.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { isReviewer } from "./roles.ts";
import { decide, isProtected, protectedEntries } from "./tool-policy.ts";

const entries = protectedEntries(
  "# comment\nquality\nhooks\nMakefile\n.claude\nCLAUDE.md\nscripts/guard\nPRODUCT.md\nacceptance\n",
);
const root = "/repo";

describe("isProtected", () => {
  it("covers a listed file, a listed directory and what is under it", () => {
    assert.equal(isProtected("Makefile", entries), true);
    assert.equal(isProtected("quality", entries), true);
    assert.equal(isProtected("quality/protected-paths.txt", entries), true);
  });

  it("does not cover a path that only starts with the same letters", () => {
    assert.equal(isProtected("qualityx/file.ts", entries), false);
    assert.equal(isProtected("clients/kmp/sharedLogic/Money.kt", entries), false);
  });
});

// Reads the real quality/protected-paths.txt (not the synthetic `entries`
// above) so the Gradle-file entries it names are checked against the actual
// registry, not a stand-in list that could drift from it.
describe("isProtected against the real quality/protected-paths.txt: Gradle wiring vs. module files", () => {
  const realEntries = protectedEntries(
    readFileSync(path.join(import.meta.dirname, "..", "..", "quality", "protected-paths.txt"), "utf8"),
  );

  it("protects the root Gradle wiring: settings, root build script, wrapper, gradle.properties", () => {
    assert.equal(isProtected("clients/kmp/settings.gradle.kts", realEntries), true);
    assert.equal(isProtected("clients/kmp/build.gradle.kts", realEntries), true);
    assert.equal(isProtected("clients/kmp/gradle.properties", realEntries), true);
    assert.equal(
      isProtected("clients/kmp/gradle/wrapper/gradle-wrapper.properties", realEntries),
      true,
    );
  });

  it("leaves each module's own build.gradle.kts and the version catalog to product work", () => {
    assert.equal(isProtected("clients/kmp/androidApp/build.gradle.kts", realEntries), false);
    assert.equal(isProtected("clients/kmp/sharedLogic/build.gradle.kts", realEntries), false);
    assert.equal(isProtected("clients/kmp/sharedUI/build.gradle.kts", realEntries), false);
    assert.equal(isProtected("clients/kmp/gradle/libs.versions.toml", realEntries), false);
  });
});

describe("decide, any session", () => {
  it("refuses an edit of a protected file, with no way to allow it", () => {
    const edit = {
      tool_name: "Edit",
      tool_input: { file_path: "/repo/quality/protected-paths.txt" },
    };

    assert.notEqual(decide(edit, root, entries), null);
  });

  it("refuses an edit of a protected path", () => {
    const edit = { tool_name: "Edit", tool_input: { file_path: "/repo/quality/x" } };

    assert.notEqual(decide(edit, root, entries), null);
  });

  it("refuses an edit of CLAUDE.md", () => {
    const write = { tool_name: "Write", tool_input: { file_path: "/repo/CLAUDE.md" } };

    assert.notEqual(decide(write, root, entries), null);
  });

  it("allows product code and tools it does not govern", () => {
    assert.equal(
      decide(
        { tool_name: "Write", tool_input: { file_path: "/repo/clients/kmp/sharedLogic/Money.kt" } },
        root,
        entries,
      ),
      null,
    );
    assert.equal(
      decide(
        { tool_name: "Read", tool_input: { file_path: "/repo/quality/commit-types.txt" } },
        root,
        entries,
      ),
      null,
    );
  });

  it("never lets a tool forge a verified stop-gate key", () => {
    const write = {
      tool_name: "Write",
      tool_input: { file_path: "/repo/.cache/stop-gate/verified" },
    };

    assert.notEqual(decide(write, root, entries), null);
  });

  it("never lets a tool write .git", () => {
    const write = { tool_name: "Write", tool_input: { file_path: "/repo/.git/config" } };

    assert.notEqual(decide(write, root, entries), null);
  });

  it("never lets a tool write the local Claude settings", () => {
    const write = {
      tool_name: "Write",
      tool_input: { file_path: "/repo/.claude/settings.local.json" },
    };

    assert.notEqual(decide(write, root, entries), null);
  });

  it("refuses a protected path reached through a symlink", () => {
    const tmpRoot = mkdtempSync(path.join(tmpdir(), "tool-policy-"));

    try {
      mkdirSync(path.join(tmpRoot, "quality"));
      symlinkSync(path.join(tmpRoot, "quality"), path.join(tmpRoot, "link"));

      const edit = {
        tool_name: "Edit",
        tool_input: { file_path: path.join(tmpRoot, "link", "x.txt") },
      };

      assert.notEqual(decide(edit, tmpRoot, entries), null);
    } finally {
      rmSync(tmpRoot, { recursive: true, force: true });
    }
  });
});

describe("decide, reviewer", () => {
  it("refuses any write inside the repository", () => {
    const write = { tool_name: "Write", tool_input: { file_path: "/repo/clients/kmp/x.kt" } };

    assert.notEqual(decide(write, root, entries, true), null);
    assert.equal(decide(write, root, entries, false), null);
  });

  it("refuses a path tool call without a string path", () => {
    assert.notEqual(decide({ tool_name: "Write", tool_input: {} }, root, entries), null);
  });
});

describe("isReviewer", () => {
  it("is true only for the reviewer agent type", () => {
    assert.equal(isReviewer({ agent_id: "a", agent_type: "reviewer" }), true);
    assert.equal(isReviewer({ agent_id: "a", agent_type: "implementer" }), false);
    assert.equal(isReviewer({}), false);
  });
});

// Ported from takamai's scripts/guard/tool-policy.test.ts: node:test + node:assert
// instead of vite-plus/test (zero npm dependencies here), Moneging paths instead of
// Go/web ones, and role coverage (scripts/guard/roles.ts) this repository adds.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { roleOf } from "./roles.ts";
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

describe("decide, restricted subagent (default role)", () => {
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

    assert.notEqual(decide(write, root, entries, "restricted"), null);
  });

  it("refuses an edit of the acceptance tests", () => {
    const write = { tool_name: "Write", tool_input: { file_path: "/repo/acceptance/shared/A.kt" } };

    assert.notEqual(decide(write, root, entries, "restricted"), null);
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

describe("decide, main session", () => {
  it("allows an edit of a protected path", () => {
    const write = { tool_name: "Write", tool_input: { file_path: "/repo/CLAUDE.md" } };

    assert.equal(decide(write, root, entries, "main"), null);
  });

  it("allows an edit under scripts/guard and acceptance/", () => {
    assert.equal(
      decide({ tool_name: "Write", tool_input: { file_path: "/repo/scripts/guard/foo.ts" } }, root, entries, "main"),
      null,
    );
    assert.equal(
      decide({ tool_name: "Write", tool_input: { file_path: "/repo/acceptance/a.kt" } }, root, entries, "main"),
      null,
    );
  });

  it("still refuses .git and the local Claude settings", () => {
    assert.notEqual(
      decide({ tool_name: "Write", tool_input: { file_path: "/repo/.git/config" } }, root, entries, "main"),
      null,
    );
    assert.notEqual(
      decide(
        { tool_name: "Write", tool_input: { file_path: "/repo/.claude/settings.local.json" } },
        root,
        entries,
        "main",
      ),
      null,
    );
  });
});

describe("decide, acceptance writer", () => {
  it("allows acceptance/", () => {
    const write = { tool_name: "Write", tool_input: { file_path: "/repo/acceptance/shared/A.kt" } };

    assert.equal(decide(write, root, entries, "acceptance-writer"), null);
  });

  it("refuses product code and the harness", () => {
    assert.notEqual(
      decide(
        { tool_name: "Write", tool_input: { file_path: "/repo/clients/kmp/sharedLogic/Money.kt" } },
        root,
        entries,
        "acceptance-writer",
      ),
      null,
    );
    assert.notEqual(
      decide({ tool_name: "Write", tool_input: { file_path: "/repo/quality/x" } }, root, entries, "acceptance-writer"),
      null,
    );
  });
});

describe("decide, path tools", () => {
  it("refuses a path tool call without a string path", () => {
    assert.notEqual(decide({ tool_name: "Write", tool_input: {} }, root, entries, "main"), null);
  });

  it("checks NotebookEdit and MultiEdit paths", () => {
    assert.notEqual(
      decide({ tool_name: "NotebookEdit", tool_input: { notebook_path: "/repo/quality/x.ipynb" } }, root, entries),
      null,
    );
    assert.notEqual(
      decide({ tool_name: "MultiEdit", tool_input: { file_path: "/repo/Makefile" } }, root, entries),
      null,
    );
  });

  it("refuses the acceptance writer anything outside acceptance/", () => {
    assert.notEqual(
      decide({ tool_name: "Write", tool_input: { file_path: "/repo/docs/handbook/x.md" } }, root, entries, "acceptance-writer"),
      null,
    );
  });
});

describe("decide, reviewer", () => {
  it("refuses any write inside the repository", () => {
    const write = { tool_name: "Write", tool_input: { file_path: "/repo/clients/kmp/x.kt" } };

    assert.notEqual(decide(write, root, entries, "reviewer"), null);
  });
});

describe("roleOf", () => {
  it("is main without an agent_id", () => {
    assert.equal(roleOf({ tool_name: "Bash" }), "main");
  });

  it("names the acceptance writer and the reviewer", () => {
    assert.equal(roleOf({ agent_id: "a", agent_type: "acceptance-writer" }), "acceptance-writer");
    assert.equal(roleOf({ agent_id: "a", agent_type: "reviewer" }), "reviewer");
  });

  it("treats a present but empty agent_id, or an agent_type alone, as a subagent", () => {
    assert.equal(roleOf({ agent_id: "" }), "restricted");
    assert.equal(roleOf({ agent_type: "implementer" }), "restricted");
    assert.equal(roleOf({ agent_id: null, agent_type: "reviewer" }), "reviewer");
  });

  it("treats every other subagent as restricted", () => {
    assert.equal(roleOf({ agent_id: "a", agent_type: "implementer" }), "restricted");
    assert.equal(roleOf({ agent_id: "a", agent_type: "general-purpose" }), "restricted");
    assert.equal(roleOf({ agent_id: "a" }), "restricted");
  });
});

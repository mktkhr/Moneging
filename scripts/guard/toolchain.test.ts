import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { check, majorOf, parseJavaVersionOutput, pinnedVersion } from "./toolchain.ts";

const MISE_TOML = `[tools]\nnode = "26.5.0"\njava = "temurin-21.0.10+7.0.LTS"\n`;

describe("pinnedVersion", () => {
  it("reads a tool's pinned version out of the [tools] table", () => {
    assert.equal(pinnedVersion(MISE_TOML, "node"), "26.5.0");
    assert.equal(pinnedVersion(MISE_TOML, "java"), "temurin-21.0.10+7.0.LTS");
  });

  it("returns null when the tool has no pin", () => {
    assert.equal(pinnedVersion(MISE_TOML, "go"), null);
  });

  it("accepts a single-quoted TOML string", () => {
    assert.equal(pinnedVersion("[tools]\nnode = '26.5.0'\n", "node"), "26.5.0");
  });

  it("accepts a trailing TOML comment", () => {
    assert.equal(pinnedVersion('[tools]\nnode = "26.5.0" # pinned for native TS\n', "node"), "26.5.0");
  });

  it("tolerates extra whitespace around the value", () => {
    assert.equal(pinnedVersion('[tools]\nnode   =   "26.5.0"   \n', "node"), "26.5.0");
  });
});

describe("majorOf", () => {
  it("reads the major version of a plain version string", () => {
    assert.equal(majorOf("26.5.0"), 26);
    assert.equal(majorOf("24.0.1"), 24);
  });

  it("reads the major version of a vendor-prefixed java version string", () => {
    assert.equal(majorOf("temurin-21.0.10+7.0.LTS"), 21);
    assert.equal(majorOf("corretto-21.0.10.7.1"), 21);
  });

  it("returns null for a string with no leading number", () => {
    assert.equal(majorOf("latest"), null);
  });

  it("does not yield null for a pre-release suffix after the version", () => {
    assert.equal(majorOf("26.5.0-rc1"), 26);
  });
});

describe("parseJavaVersionOutput", () => {
  it("reads the major version out of an openjdk banner", () => {
    assert.equal(
      parseJavaVersionOutput('openjdk version "21.0.10" 2026-01-20 LTS\nOpenJDK Runtime Environment\n'),
      21,
    );
  });

  it("reads the major version out of an oracle-style banner", () => {
    assert.equal(parseJavaVersionOutput('java version "17.0.2" 2022-01-18\n'), 17);
  });

  it("reads Java 8's legacy 1.MAJOR.MINOR_UPDATE scheme as major 8, not 1", () => {
    assert.equal(parseJavaVersionOutput('java version "1.8.0_392"\n'), 8);
  });

  it("returns null when the text has no version banner", () => {
    assert.equal(parseJavaVersionOutput("command not found\n"), null);
  });
});

describe("check", () => {
  it("returns null when the running major matches the pin", () => {
    assert.equal(check(MISE_TOML, "node", 26), null);
    assert.equal(check(MISE_TOML, "java", 21), null);
  });

  it("reports a mismatch when the running major differs from the pin", () => {
    assert.deepEqual(check(MISE_TOML, "node", 20), {
      tool: "node",
      pinned: "26.5.0",
      pinnedMajor: 26,
      runningMajor: 20,
    });
  });

  it("reports a mismatch when the tool could not be found at all (null running major)", () => {
    assert.deepEqual(check(MISE_TOML, "java", null), {
      tool: "java",
      pinned: "temurin-21.0.10+7.0.LTS",
      pinnedMajor: 21,
      runningMajor: null,
    });
  });

  it("returns null when the tool has no pin in mise.toml", () => {
    assert.equal(check(MISE_TOML, "go", 1), null);
  });

  it("returns null when the pin itself does not parse as a version", () => {
    assert.equal(check('[tools]\nnode = "latest"\n', "node", 26), null);
  });
});

// The CLI's normal root resolution is derived from this file's own location
// (always the real repository), so these pass an explicit root argument -
// the same override the other guard CLIs support - to point
// it at a throwaway mise.toml instead.
describe("CLI", () => {
  const CLI = path.join(import.meta.dirname, "toolchain.ts");

  function makeRoot(miseToml: string): string {
    const root = mkdtempSync(path.join(tmpdir(), "toolchain-cli-"));

    writeFileSync(path.join(root, "mise.toml"), miseToml);

    return root;
  }

  it("fails with a clear message when mise.toml has no pin for a tool this guard checks", () => {
    const root = makeRoot('[tools]\nnode = "26.5.0"\n'); // no java pin at all

    try {
      const result = spawnSync("node", [CLI, root], { encoding: "utf8" });

      assert.equal(result.status, 1);
      assert.match(result.stderr, /mise\.toml has no java pin/u);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("passes when the running node/java majors match an explicit root's mise.toml", () => {
    const root = makeRoot(
      `[tools]\nnode = "${process.version.replace(/^v/u, "")}"\njava = "temurin-999.0.0"\n`,
    );

    try {
      // java's major (999) deliberately does not match anything real, so
      // only node's outcome is asserted; this proves the explicit root
      // argument, not $CLAUDE_PROJECT_DIR or cwd, is what got read.
      const result = spawnSync("node", [CLI, root], { encoding: "utf8" });

      assert.doesNotMatch(result.stderr, /no node pin|node is major/u);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});

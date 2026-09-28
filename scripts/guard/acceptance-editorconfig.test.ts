/**
 * ktlint reads its rules from the nearest .editorconfig with `root = true`.
 * acceptance/shared lives outside clients/kmp, so it carries a copy of
 * clients/kmp/.editorconfig; this keeps the copy from drifting.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, it } from "node:test";

const root = path.resolve(import.meta.dirname, "../..");

describe("acceptance/shared/.editorconfig", () => {
  it("is identical to clients/kmp/.editorconfig", () => {
    assert.equal(
      readFileSync(path.join(root, "acceptance/shared/.editorconfig"), "utf8"),
      readFileSync(path.join(root, "clients/kmp/.editorconfig"), "utf8"),
    );
  });
});

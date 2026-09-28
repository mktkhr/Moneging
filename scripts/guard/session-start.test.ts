import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { nodeVersionWarning } from "./session-start.ts";

const MISE_TOML = '[tools]\nnode = "26.5.0"\njava = "temurin-21.0.10+7.0.LTS"\n';

describe("nodeVersionWarning", () => {
  it("warns when the running node is older than the pin", () => {
    const warning = nodeVersionWarning(MISE_TOML, "v20.11.0");

    assert.match(warning ?? "", /node v20\.11\.0 does not match mise\.toml's pin \(node 26\.5\.0\)/u);
  });

  it("warns when the running node is newer than the pin too", () => {
    const warning = nodeVersionWarning(MISE_TOML, "v27.0.0");

    assert.match(warning ?? "", /node v27\.0\.0 does not match mise\.toml's pin \(node 26\.5\.0\)/u);
  });

  it("is silent when the running node matches the pin's major", () => {
    assert.equal(nodeVersionWarning(MISE_TOML, "v26.5.0"), null);
  });

  it("is silent when mise.toml could not be read", () => {
    assert.equal(nodeVersionWarning(null, "v20.0.0"), null);
  });

  it("is silent when mise.toml has no node pin", () => {
    assert.equal(nodeVersionWarning('[tools]\njava = "temurin-21.0.10+7.0.LTS"\n', "v20.0.0"), null);
  });
});

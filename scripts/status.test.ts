import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, it } from "node:test";

import {
  junitCases,
  parseCriteria,
  parseGates,
  parseMakeExit,
  resolve,
  xcresultTitled,
} from "./status.ts";
import { openStage, parseStages } from "./status-stage.ts";

const product = `
| ID       | Criterion                    | Test                          |
| -------- | ---------------------------- | ----------------------------- |
| AC-B-104 | A ledger is created and listed. | \`TestCreateLedger\`       |
| AC-B-107 | Isolation.                   | \`TestLedgerIsolation\`         |
| AC-B-108 | Sync-ready records.          | \`TestRecordsAreSyncReady\`     |
| AC-F-102 | Onboarding creates a ledger. | \`AC-F-102\`                    |
| AC-E-101 | First launch, offline.       | \`AC-E-101\`                    |
| AC-F-201 | The month's list.            | \`AC-F-201\`                    |
`;

const androidXml = `<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="io.github.mktkhr.moneging.acceptance.TestCreateLedger" tests="2">
  <testcase name="createsAndLists" classname="io.github.mktkhr.moneging.acceptance.TestCreateLedger" time="0.01"/>
  <testcase name="keepsName &quot;家計&quot;" classname="io.github.mktkhr.moneging.acceptance.TestCreateLedger" time="0.01">
  </testcase>
  <testcase name="TestLedgerIsolation" classname="io.github.mktkhr.moneging.acceptance.LedgerTests" time="0.01">
    <failure message="Expected &lt;1&gt;" type="AssertionError">trace</failure>
  </testcase>
  <testcase name="TestRecordsAreSyncReady" classname="io.github.mktkhr.moneging.acceptance.LedgerTests" time="0.01"/>
</testsuite>
`;

const iosXml = `<testsuite name="iosSimulatorArm64Test.io.github.mktkhr.moneging.acceptance.TestCreateLedger">
  <testcase name="createsAndLists[iosSimulatorArm64]" classname="iosSimulatorArm64Test.io.github.mktkhr.moneging.acceptance.TestCreateLedger" time="0.001"/>
  <testcase name="TestLedgerIsolation[iosSimulatorArm64]" classname="iosSimulatorArm64Test.io.github.mktkhr.moneging.acceptance.LedgerTests" time="0.001"/>
</testsuite>
`;

const xcresult = {
  testNodes: [
    {
      name: "iosAppAcceptance",
      nodeType: "Test Plan",
      result: "Failed",
      children: [
        {
          name: "iosAppAcceptanceTests",
          nodeType: "UI test bundle",
          children: [
            {
              name: "OnboardingTests",
              nodeType: "Test Suite",
              children: [
                { name: "test_AC_F_102_createsLedger()", nodeType: "Test Case", result: "Passed" },
                { name: "test_AC_E_101_opensOffline()", nodeType: "Test Case", result: "Failed" },
                { name: "test_AC_F_201_listsMonth()", nodeType: "Test Case", result: "Skipped" },
              ],
            },
          ],
        },
      ],
    },
  ],
};

describe("parseCriteria", () => {
  it("reads every criterion row and the test it names", () => {
    assert.deepEqual(parseCriteria(product), [
      { id: "AC-B-104", test: "TestCreateLedger" },
      { id: "AC-B-107", test: "TestLedgerIsolation" },
      { id: "AC-B-108", test: "TestRecordsAreSyncReady" },
      { id: "AC-F-102", test: "AC-F-102" },
      { id: "AC-E-101", test: "AC-E-101" },
      { id: "AC-F-201", test: "AC-F-201" },
    ]);
  });

  it("reads the real PRODUCT.md §7", () => {
    const doc = readFileSync(path.resolve(import.meta.dirname, "../PRODUCT.md"), "utf8");
    const criteria = parseCriteria(doc);

    assert.deepEqual(criteria[0], { id: "AC-B-104", test: "TestCreateLedger" });
    assert.ok(criteria.some((c) => c.id === "AC-E-111" && c.test === "AC-E-111"));
    assert.equal(new Set(criteria.map((c) => c.id)).size, criteria.length);
  });
});

describe("parseGates", () => {
  it("reads ok and FAIL lines and ignores the rest", () => {
    const log =
      "ok: harness-check:scripts\nsome diagnostic\nFAIL: lint:detekt (exit 1)\nok: ios-ui-test (skipped: unchanged)\nmake: *** [x] Error 1\n";

    assert.deepEqual(parseGates(log), [
      { name: "harness-check:scripts", ok: true },
      { name: "lint:detekt", ok: false },
      { name: "ios-ui-test", ok: true },
    ]);
  });
});

describe("parseMakeExit", () => {
  it("reads the exit code on the last make-exit line", () => {
    assert.equal(parseMakeExit("ok: fmt\nmake-exit: 0\n"), 0);
    assert.equal(parseMakeExit("ok: fmt\nFAIL: lint (exit 1)\nmake-exit: 2\n"), 2);
    assert.equal(parseMakeExit("ok: fmt\nFAIL: lint (exit 1)\n"), null);
  });
});

describe("parseStages", () => {
  it("reads the real PRODUCT.md §8 stages, ranges expanded", () => {
    const doc = readFileSync(path.resolve(import.meta.dirname, "../PRODUCT.md"), "utf8");
    const stages = parseStages(doc);

    assert.deepEqual(stages.get(1), [
      "AC-B-104",
      "AC-B-107",
      "AC-B-108",
      "AC-B-109",
      "AC-F-102",
      "AC-F-103",
      "AC-F-104",
      "AC-E-101",
    ]);
    assert.deepEqual(stages.get(4), ["AC-B-401", "AC-B-402", "AC-B-403", "AC-F-401"]);
    assert.deepEqual(stages.get(9), ["AC-F-701"]);
  });

  it("reads only the §8 section", () => {
    const doc = "## 5. UI\n\n1. **Not a stage** — AC-F-999.\n\n## 8. Delivery order\n\n1. **Foundation** — AC-B-104.\n\n## 9. Done\n";

    assert.deepEqual([...parseStages(doc)], [[1, ["AC-B-104"]]]);
  });
});

describe("openStage", () => {
  it("reads the first non-comment, non-blank line as the stage number", () => {
    assert.equal(openStage("# c\n0\n"), 0);
    assert.equal(openStage("# c\n3\n"), 3);
    assert.equal(openStage("x\n"), 0);
  });

  it("reads the real quality/stage.txt", () => {
    const text = readFileSync(path.resolve(import.meta.dirname, "../quality/stage.txt"), "utf8");

    assert.ok(Number.isInteger(openStage(text)));
  });
});

describe("junitCases", () => {
  it("reads each test case, its class and whether it passed", () => {
    assert.deepEqual(junitCases(androidXml, "testAndroidHostTest"), [
      {
        target: "testAndroidHostTest",
        className: "io.github.mktkhr.moneging.acceptance.TestCreateLedger",
        name: "createsAndLists",
        pass: true,
      },
      {
        target: "testAndroidHostTest",
        className: "io.github.mktkhr.moneging.acceptance.TestCreateLedger",
        name: 'keepsName "家計"',
        pass: true,
      },
      {
        target: "testAndroidHostTest",
        className: "io.github.mktkhr.moneging.acceptance.LedgerTests",
        name: "TestLedgerIsolation",
        pass: false,
      },
      {
        target: "testAndroidHostTest",
        className: "io.github.mktkhr.moneging.acceptance.LedgerTests",
        name: "TestRecordsAreSyncReady",
        pass: true,
      },
    ]);
  });

  it("counts a skipped test as not passing", () => {
    const xml = '<testcase name="a" classname="C"><skipped/></testcase>';

    assert.equal(junitCases(xml, "t")[0]?.pass, false);
  });
});

describe("xcresultTitled", () => {
  it("titles each test case with its suite; only Passed passes", () => {
    assert.deepEqual(xcresultTitled(xcresult), [
      { title: "OnboardingTests test_AC_F_102_createsLedger()", pass: true },
      { title: "OnboardingTests test_AC_E_101_opensOffline()", pass: false },
      { title: "OnboardingTests test_AC_F_201_listsMonth()", pass: false },
    ]);
  });

  it("reads nothing from a result without tests", () => {
    assert.deepEqual(xcresultTitled({ testNodes: [{ name: "p", nodeType: "Test Plan" }] }), []);
    assert.deepEqual(xcresultTitled(null), []);
  });
});

describe("resolve", () => {
  it("marks each criterion pass, fail or missing from what actually ran", () => {
    const shared = [
      ...junitCases(androidXml, "testAndroidHostTest"),
      ...junitCases(iosXml, "iosSimulatorArm64Test"),
    ];

    assert.deepEqual(resolve(parseCriteria(product), shared, xcresultTitled(xcresult)), [
      // Class TestCreateLedger, every case passed on both targets.
      { id: "AC-B-104", test: "TestCreateLedger", result: "pass" },
      // Function TestLedgerIsolation failed on the Android host.
      { id: "AC-B-107", test: "TestLedgerIsolation", result: "fail" },
      // Passed, but never ran on the iOS simulator.
      { id: "AC-B-108", test: "TestRecordsAreSyncReady", result: "fail" },
      { id: "AC-F-102", test: "AC-F-102", result: "pass" },
      { id: "AC-E-101", test: "AC-E-101", result: "fail" },
      { id: "AC-F-201", test: "AC-F-201", result: "fail" },
    ]);
  });

  it("is missing everything when nothing ran", () => {
    assert.deepEqual(
      resolve(parseCriteria(product), [], []).map((r) => r.result),
      ["missing", "missing", "missing", "missing", "missing", "missing"],
    );
  });
});

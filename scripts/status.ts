/**
 * Writes test-results/STATUS.md from what actually ran: the gate lines of
 * `make -k check` (test-results/check.log) and the results of the acceptance
 * suites, matched against the criteria of PRODUCT.md §7:
 * - AC-B: the JUnit XML of acceptance/shared (Gradle, Android host and iOS
 *   simulator) under clients/kmp/build/acceptance-shared/test-results;
 * - AC-F / AC-E: the XCUITests of acceptance/ios, read from
 *   test-results/acceptance/ios.xcresult with `xcrun xcresulttool`.
 *
 * Nobody writes status by hand. Run through `make status`.
 */
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

import { openStage, parseStages } from "./status-stage.ts";

export interface Criterion {
  readonly id: string;
  readonly test: string;
}

export interface Gate {
  readonly name: string;
  readonly ok: boolean;
}

export interface Titled {
  readonly title: string;
  readonly pass: boolean;
}

/** One `<testcase>` of a JUnit XML report, with the Gradle test task that wrote it. */
export interface JUnitCase {
  readonly target: string;
  readonly className: string;
  readonly name: string;
  readonly pass: boolean;
}

export type Result = "pass" | "fail" | "missing";

/** The Gradle test tasks of acceptance/shared: every AC-B test runs on each. */
export const SHARED_TARGETS = ["testAndroidHostTest", "iosSimulatorArm64Test"] as const;

const root = path.resolve(import.meta.dirname, "..");
const sharedResults = "clients/kmp/build/acceptance-shared/test-results";
const iosResult = "test-results/acceptance/ios.xcresult";

/** Every `| AC-X-NNN | ... | \`test\` |` row. */
export function parseCriteria(product: string): Criterion[] {
  const rows: Criterion[] = [];

  for (const line of product.split("\n")) {
    const match = /^\|\s*(AC-[BFE]-\d{3})\s*\|.*\|\s*`([^`]+)`\s*\|\s*$/u.exec(line);

    if (match?.[1] !== undefined && match[2] !== undefined)
      rows.push({ id: match[1], test: match[2] });
  }

  return rows;
}

/** The `ok: <gate>` and `FAIL: <gate> (exit n)` lines scripts/quiet.sh prints. */
export function parseGates(log: string): Gate[] {
  const gates: Gate[] = [];

  for (const line of log.split("\n")) {
    const match = /^(ok|FAIL): (\S+)/u.exec(line);

    if (match?.[1] !== undefined && match[2] !== undefined)
      gates.push({ name: match[2], ok: match[1] === "ok" });
  }

  return gates;
}

/** The exit code of the last `make-exit: N` line, or null when there is none. */
export function parseMakeExit(log: string): number | null {
  let exit: number | null = null;

  for (const line of log.split("\n")) {
    const match = /^make-exit: (-?\d+)$/u.exec(line);

    if (match?.[1] !== undefined) exit = Number(match[1]);
  }

  return exit;
}

function unescapeXml(text: string): string {
  return text
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'")
    .replaceAll("&amp;", "&");
}

function attribute(tag: string, name: string): string {
  const match = new RegExp(`\\s${name}="([^"]*)"`, "u").exec(tag);

  return match?.[1] === undefined ? "" : unescapeXml(match[1]);
}

/**
 * The test cases of one Gradle JUnit XML report. A case passes when it has no
 * `<failure>`, `<error>` or `<skipped>` child: a skipped test proves nothing.
 */
export function junitCases(xml: string, target: string): JUnitCase[] {
  const cases: JUnitCase[] = [];
  const pattern = /<testcase\b([^>]*?)(\/>|>([\s\S]*?)<\/testcase>)/gu;

  for (const match of xml.matchAll(pattern)) {
    const tag = match[1] ?? "";
    const body = match[3] ?? "";

    cases.push({
      target,
      className: attribute(tag, "classname"),
      name: attribute(tag, "name"),
      pass: !/<(failure|error|skipped)\b/u.test(body),
    });
  }

  return cases;
}

interface XcNode {
  readonly name?: string;
  readonly nodeType?: string;
  readonly result?: string;
  readonly children?: readonly XcNode[];
}

/** Structural conversion of a parsed JSON value into an XcNode, no field left unchecked. */
function toXcNode(value: unknown): XcNode {
  if (typeof value !== "object" || value === null) return {};

  const text = (key: string): string | undefined =>
    key in value && typeof (value as Record<string, unknown>)[key] === "string"
      ? ((value as Record<string, unknown>)[key] as string)
      : undefined;
  const children =
    "children" in value && Array.isArray(value.children)
      ? value.children.map(toXcNode)
      : undefined;
  const name = text("name");
  const nodeType = text("nodeType");
  const result = text("result");

  return {
    ...(name === undefined ? {} : { name }),
    ...(nodeType === undefined ? {} : { nodeType }),
    ...(result === undefined ? {} : { result }),
    ...(children === undefined ? {} : { children }),
  };
}

/**
 * Test titles (`<suite> <test>`) and outcomes from
 * `xcrun xcresulttool get test-results tests` output. Only "Passed" passes.
 */
export function xcresultTitled(report: unknown): Titled[] {
  const found: Titled[] = [];
  const top =
    typeof report === "object" && report !== null && "testNodes" in report
      ? toXcNode({ children: report.testNodes })
      : {};

  const walk = (node: XcNode, suite: string): void => {
    if (node.nodeType === "Test Case") {
      found.push({
        title: `${suite} ${node.name ?? ""}`.trim(),
        pass: node.result === "Passed",
      });

      return;
    }

    const next = node.nodeType === "Test Suite" ? (node.name ?? suite) : suite;

    for (const child of node.children ?? []) walk(child, next);
  };

  walk(top, "");

  return found;
}

/** The last segment of a dotted class name (package and Gradle target prefix removed). */
function simpleName(className: string): string {
  return className.slice(className.lastIndexOf(".") + 1);
}

/** A test name without the `[iosSimulatorArm64]` suffix Kotlin/Native adds. */
function bareName(name: string): string {
  return name.replace(/\[[^\]]*\]$/u, "");
}

/** Whether a title carries the criterion's identifier, as `AC-F-102` or `AC_F_102`. */
function carriesId(title: string, id: string): boolean {
  return title.includes(id) || title.includes(id.replaceAll("-", "_"));
}

function outcome(passes: readonly boolean[]): Result {
  if (passes.length === 0) return "missing";

  return passes.every(Boolean) ? "pass" : "fail";
}

/**
 * pass when every test for the criterion passed, fail when one did not,
 * missing when none ran. An AC-B test is found by its PRODUCT.md test name
 * (the test class or the test function) or by the identifier in either, and
 * must have run on every target of SHARED_TARGETS; an AC-F / AC-E test by
 * the identifier in its title.
 */
export function resolve(
  criteria: readonly Criterion[],
  shared: readonly JUnitCase[],
  titled: readonly Titled[],
): (Criterion & { readonly result: Result })[] {
  return criteria.map((criterion) => {
    if (criterion.id.startsWith("AC-B-")) {
      const matching = shared.filter(
        (test) =>
          simpleName(test.className) === criterion.test ||
          bareName(test.name) === criterion.test ||
          carriesId(`${test.className} ${test.name}`, criterion.id),
      );
      const everyTarget = SHARED_TARGETS.every((target) =>
        matching.some((test) => test.target === target),
      );
      const result = outcome(matching.map((test) => test.pass));

      return { ...criterion, result: result === "pass" && !everyTarget ? "fail" : result };
    }

    const matching = titled.filter((test) => carriesId(test.title, criterion.id));

    return { ...criterion, result: outcome(matching.map((test) => test.pass)) };
  });
}

function read(relative: string): string {
  const file = path.join(root, relative);

  return existsSync(file) ? readFileSync(file, "utf8") : "";
}

/** Every JUnit XML report under clients/kmp/build/acceptance-shared/test-results/<task>/. */
function readSharedCases(): JUnitCase[] {
  const dir = path.join(root, sharedResults);

  if (!existsSync(dir)) return [];

  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .flatMap((task) =>
      readdirSync(path.join(dir, task.name), { recursive: true, encoding: "utf8" })
        .filter((file) => file.endsWith(".xml"))
        .flatMap((file) =>
          junitCases(readFileSync(path.join(dir, task.name, file), "utf8"), task.name),
        ),
    );
}

/** The XCUITest outcomes of the last `make acceptance-ios`, none when it has not run. */
function readIosTitled(): Titled[] {
  const bundle = path.join(root, iosResult);

  if (!existsSync(bundle)) return [];

  const json = execFileSync(
    "xcrun",
    ["xcresulttool", "get", "test-results", "tests", "--path", bundle],
    { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
  );

  return xcresultTitled(JSON.parse(json));
}

function git(...args: string[]): string {
  return execFileSync("git", args, { cwd: root, encoding: "utf8" }).trim();
}

/** Every criterion resolved against what the acceptance suites actually ran. */
function acceptanceResults(criteria: readonly Criterion[]): (Criterion & { result: Result })[] {
  return resolve(criteria, readSharedCases(), readIosTitled());
}

function run(): number {
  const log = read("test-results/check.log");
  const gates = parseGates(log);
  const failedGates = gates.filter((gate) => !gate.ok);
  const makeExit = parseMakeExit(log);
  const green = gates.length > 0 && failedGates.length === 0 && makeExit === 0;
  const results = acceptanceResults(parseCriteria(read("PRODUCT.md")));
  const passing = results.filter((result) => result.result === "pass").length;
  const dirty = git("status", "--porcelain") === "" ? "clean" : "uncommitted changes";
  const exitNote = `make exit: ${makeExit ?? "unknown"}`;
  const open = openStage(read("quality/stage.txt"));

  const lines = [
    "# STATUS",
    "",
    `Generated by \`make status\` at ${new Date().toISOString()} for ${git("rev-parse", "--short", "HEAD")} (${dirty}). Do not edit.`,
    "",
    `**make check: ${green ? "GREEN" : "RED"}** (${gates.length - failedGates.length}/${gates.length} gates ok)`,
    ...(green ? [] : [exitNote]),
    "",
    ...failedGates.map((gate) => `- FAIL: ${gate.name}`),
    "",
    `## Acceptance criteria: ${passing}/${results.length} passing (open stage: ${open})`,
    "",
    ...results.map((result) => `- ${result.result.toUpperCase()} ${result.id} \`${result.test}\``),
    "",
  ];

  writeFileSync(path.join(root, "test-results/STATUS.md"), lines.join("\n"));
  console.log(
    `status: make check ${green ? "GREEN" : "RED"}, ${passing}/${results.length} acceptance criteria passing${green ? "" : `, ${exitNote}`} (test-results/STATUS.md)`,
  );

  return 0;
}

/** `node scripts/status.ts --gate`: every criterion of the open stage must pass. */
function checkStageGate(): number {
  const open = openStage(read("quality/stage.txt"));

  if (open === 0) {
    console.log("acceptance-gate: no stage open yet");

    return 0;
  }

  const stages = parseStages(read("PRODUCT.md"));
  const required = new Set<string>();

  for (let stage = 1; stage <= open; stage += 1) {
    for (const id of stages.get(stage) ?? []) required.add(id);
  }

  const criteria = parseCriteria(read("PRODUCT.md")).filter((criterion) =>
    required.has(criterion.id),
  );
  const results = acceptanceResults(criteria);
  const failing = results.filter((result) => result.result !== "pass");

  if (failing.length === 0) {
    console.log(`acceptance-gate: stage ${open}, ${results.length} criteria required, all pass`);

    return 0;
  }

  console.log(
    `acceptance-gate: stage ${open}: ${failing.map((result) => `${result.id} ${result.result}`).join(", ")}`,
  );

  return 1;
}

if (process.argv[1] !== undefined && path.resolve(process.argv[1]) === import.meta.filename) {
  process.exitCode = process.argv.includes("--gate") ? checkStageGate() : run();
}

/**
 * PRODUCT.md §8 (delivery order) and quality/stage.txt (the open stage):
 * pure parsing, no filesystem access. Used by scripts/status.ts.
 */

/**
 * PRODUCT.md §8 delivery stages: `<n>. **<Name>** — ... <ids>.` where ids are
 * `AC-X-NNN` singles and `AC-X-NNN to AC-X-MMM` ranges (same prefix, expanded
 * inclusively). Only the `## 8.` section is read, so a numbered bold list
 * elsewhere in the spec is never taken for a stage.
 */
export function parseStages(product: string): Map<number, string[]> {
  const stages = new Map<number, string[]>();
  const section = /^## 8\.[^\n]*\n([\s\S]*?)(?=^## |(?![\s\S]))/mu.exec(product)?.[1] ?? "";
  const entries = section.match(/^(\d+)\.\s+\*\*[^\n]*(?:\n(?!\d+\.\s+\*\*)[^\n]*)*/gmu) ?? [];

  for (const entry of entries) {
    const number = /^(\d+)\./u.exec(entry)?.[1];

    if (number === undefined) continue;

    const ids: string[] = [];
    const withoutRanges = entry.replaceAll(
      /AC-([BFE])-(\d{3}) to AC-\1-(\d{3})/gu,
      (_full: string, letter: string, start: string, end: string) => {
        for (let n = Number(start); n <= Number(end); n += 1)
          ids.push(`AC-${letter}-${String(n).padStart(3, "0")}`);

        return "";
      },
    );

    ids.push(...(withoutRanges.match(/AC-[BFE]-\d{3}/gu) ?? []));
    stages.set(Number(number), ids);
  }

  return stages;
}

/** The stage number on the first non-comment, non-blank line, else 0. */
export function openStage(text: string): number {
  for (const line of text.split("\n")) {
    const trimmed = line.trim();

    if (trimmed === "" || trimmed.startsWith("#")) continue;

    return /^\d+$/u.test(trimmed) ? Number(trimmed) : 0;
  }

  return 0;
}

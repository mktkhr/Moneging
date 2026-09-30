# acceptance/fixtures

Material shared by the shared-logic tests (`AC-B-5xx`) and the UI tests
(`AC-F-501`, `AC-F-504`, `AC-E-501`). The receipts are fictional.

```
receipts/
  seven-eleven.jpg   corner-deli.jpg              the pictures (drawn, see below)
  seven-eleven.json  corner-deli.json             the draft the fixture scanner answers
receipt-text/
  seven-eleven.txt   corner-deli.txt              the text Vision read from the pictures
  seven-eleven.rule.json  corner-deli.rule.json   what the rule-based parser must produce from it
  seven-eleven.llm.json                           what the fake on-device LLM answers
tools/
  draw_receipts.py   draws receipts/*.jpg
  ocr.swift          produces receipt-text/*.txt
```

## Draft JSON format

Every `.json` here is one draft, in the same shape:

```json
{
  "store": { "value": "セブン-イレブン", "confidence": 0.95 },
  "date":  { "value": "2026-02-14", "confidence": 0.9 },
  "total": { "value": 1180, "confidence": 0.4 },
  "items": [
    { "name": "おにぎり", "amount": 380, "category": "食費", "confidence": 0.9 },
    { "name": "弁当", "amount": 800, "category": null, "confidence": 0.5 }
  ]
}
```

`date` is an ISO date, amounts are integer yen, `category` is a default
category name or `null` (none), confidences are numbers from 0 to 1. Items
keep the order of the receipt. A draft has no category of its own.

## The rule-based parser (`*.rule.json`)

Deterministic, from the recognised text, one receipt row per line:

- store: the first line.
- date: the first `yyyy/mm/dd` in the text, as `yyyy-mm-dd`.
- total: the amount (`¥` and digits, commas allowed) on the line that starts
  with `合計`.
- items: the lines after the date line and before the first line that starts
  with `小計` or `合計`, that end with an amount, except lines that start with
  `+` (an add-on such as `+ LARGE RICE ¥150`, not read as an item). The name is
  the text before the amount.
- category: none (`null`) for every item; the parser does not classify.
- confidence: every field and item it read has the constant 0.7.

## Regenerating

From the repository root:

```
python3 acceptance/fixtures/tools/draw_receipts.py acceptance/fixtures/receipts
swift acceptance/fixtures/tools/ocr.swift acceptance/fixtures/receipts/seven-eleven.jpg \
  > acceptance/fixtures/receipt-text/seven-eleven.txt
swift acceptance/fixtures/tools/ocr.swift acceptance/fixtures/receipts/corner-deli.jpg \
  > acceptance/fixtures/receipt-text/corner-deli.txt
```

`draw_receipts.py` needs Pillow and macOS's Hiragino Sans. `ocr.swift` runs
Vision (`.accurate`, `["ja-JP", "en-US"]`, language correction at its
default) and joins the left and right observations of a row into one line.
The recorded text depends on the macOS version: after regenerating it, check
that `*.rule.json` still describes what the parser must read from it.

## How the tests find these files

The shared-logic tests read the directory named by the environment variable
`MONEGING_FIXTURES` (set by `acceptance/shared/build.gradle.kts`), else the
nearest `fixtures` or `acceptance/fixtures` above the working directory. The
iOS UI tests pass the app the absolute path of this directory in the launch
argument `-UITestScannerFixtures` (`acceptance/ios/XCUIApplication+Scanning.swift`).

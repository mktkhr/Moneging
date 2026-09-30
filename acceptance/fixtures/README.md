# acceptance/fixtures

Material shared by the shared-logic tests (`AC-B-5xx`) and the UI tests
(`AC-F-501`, `AC-F-504`, `AC-E-501`). Two receipts are drawn and fictional;
four are the recognised text of real receipts, with what identifies a person
or a payment masked (below). The pictures of the real receipts are not kept
here.

```
receipts/
  seven-eleven.jpg   corner-deli.jpg              the pictures (drawn, see below)
  seven-eleven.json  corner-deli.json             the draft the fixture scanner answers
receipt-text/
  seven-eleven.txt   corner-deli.txt              the text Vision read from the drawn pictures
  maruetsu-petit.txt                              a supermarket that adds tax and marks a discount
  seven-eleven-shiba.txt                          a convenience store with a discount and a quantity
  life.txt                                        a supermarket with quantities, a sticker discount and added tax
  ubereats-gongcha.txt                            a delivery order with options
  <name>.rule.json                                what the rule-based parser must produce from <name>.txt
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

Deterministic, from the recognised text, one receipt row per line. It reads a
receipt as a shopper reads it (`PRODUCT.md` §3, Draft).

### Chain names

The device keeps a list of well-known chains. It must contain at least these
names, each with the spellings a receipt prints it in:

| Name              | Spellings                             |
|-------------------|---------------------------------------|
| `ライフ`          | `ライフ`                              |
| `マルエツ プチ`   | `マルエツ プチ`, `maruetsu petit`     |
| `セブン-イレブン` | `セブン-イレブン`                     |
| `ゴンチャ`        | `ゴンチャ`                            |

A spelling is found in the text with its lines joined by spaces, letters
compared without case (the マルエツ プチ receipt prints its logo as the lines
`maruetsu` and `petit`).

### Fields

- store: the name of the chain whose spelling appears first in the text; when
  none appears, the first line.
- date: the first `yyyy/mm/dd` or `yyyy年mm月dd日` (two-digit month and day)
  in the text, as `yyyy-mm-dd`.
- total: the amount on the first line that starts with `合計` (`合計 ¥5,315`,
  `合計金額 ¥2,330`).
- category: none (`null`) for every item; the parser does not classify.
- confidence: every field and item it read has the constant 0.7, the added
  `消費税` item too.

### Items

The item lines are those after the date line and before the first line that
starts with `小計`, `合計`, `（` or `(` (a summary such as `（商品代金 ¥2,178）`).

An **amount** is the last space-separated token of a line when it is a number
of yen: an optional reduced-tax mark `*` or `＊`, an optional `¥` or `￥`, an
optional `-`, digits with a comma every three from the right (`3,280`; `6501`
is not an amount), and an optional `※`. `50%`, `15:48` and `登録No0000` are not
amounts. A line that ends with a lone `¥` continues on the next line: the two
are read as one line joined by a space (`■ JUICY巨峰ミルクティー JUICY ¥` and
`Kyoho Grape Milk Tea 1,010`).

Each item line is, in this order:

1. a **quantity line** — it starts with a quantity and a unit price
   (`2コ✕単178 ¥356`, `2コX単-99 -198`, `@159x 3 *477`; `X`, `x`, `✕`, `×`):
   its amount is the amount of the line without an amount right above it (an
   item's name, `キリンファイアワンデイブラック600ml`), and when that line is a
   discount (`シール割引 50%`), the discount's.
2. a **discount line** — its text contains `値引` or `割引` (`値引額 -50`,
   `★割引（20%） -120`, `シール割引`): its amount, below zero, is added to the
   item above, the discount's own amount or that of the quantity line below it.
3. an **option line** — it starts with `+` (`+ LARGE RICE ¥150`), or the text
   before its amount contains `※` (`氷Ice※通常 ¥120`): its amount is added to
   the item above. It is not an item.
4. an **item** — any other line with an amount: its amount and its name.
5. any other line without an amount — the name of the item when a quantity
   line follows it, else not read (`ICED/Mサイズ`, `★売変@499 →@199`).

An item's **name** is the text of its line before the amount, with, from its
start, a delivery order's check box dropped (in a receipt whose first line is
`Uber Eats`, a leading `ロ`, `■` or `□` and the space after it), then the
reduced-tax mark `*` or `＊`, then an item code of three digits and the space
after it (`651 アキタコマチ5`, `344野菜炒め`). The rest is kept as it was
recognised, spaces and misreadings included (`A 豚こまぎれ`,
`ヤマキめんつゆ50（`): the parser does not correct the text.

### Added tax

When the text shows that the items exclude tax — a line containing `外税`,
`外8%`, `外10%` or `税抜` — the parser adds, after the items, one item
`消費税` of the total minus the items' sum, without a category, so that the
items add up to the total. Tax included in the prices (`内消費税等`) adds
nothing.

## The real receipts

Each `.txt` of a real receipt is what `ocr.swift` read from its photograph,
then masked. Masked are, digit by digit: register (`レジ`, `登録機`) numbers,
transaction, slip, order, receipt and terminal numbers (`登録No`, `取引通番`,
`端末識別番号`, `伝票番号`, `オーダー明細ID`, `レシートNo`, the `#…` and `No.…`
numbers), the staff member's number (`責`, `No…：応援者`), campaign serial
numbers, the orderer's name and the order number. A masked digit becomes `0`,
a masked letter or character of a name `X` (`X0000`, `X・XX`, `責：00000000XX`);
punctuation stays, so every masked value keeps its length. Kept are the store
name, its address and telephone, the business registration number (`登録番号`,
`事業者登録番号`, the store's, printed on every receipt), the store number,
dates and times, item names, amounts, totals and tax. The text is not
otherwise corrected: misreadings stay as recognised.

## Regenerating

From the repository root:

```
python3 acceptance/fixtures/tools/draw_receipts.py acceptance/fixtures/receipts
swift acceptance/fixtures/tools/ocr.swift acceptance/fixtures/receipts/seven-eleven.jpg \
  > acceptance/fixtures/receipt-text/seven-eleven.txt
swift acceptance/fixtures/tools/ocr.swift acceptance/fixtures/receipts/corner-deli.jpg \
  > acceptance/fixtures/receipt-text/corner-deli.txt
```

`draw_receipts.py` needs Pillow and macOS's Hiragino Sans. `ocr.swift` first
straightens the photograph as the document scanner straightens its pages (the
receipt's four corners from `VNDetectDocumentSegmentationRequest`, mapped to a
rectangle by `CIPerspectiveCorrection`; a drawn picture, all paper, is read as
it is), then runs Vision (`.accurate`, `["ja-JP", "en-US"]`, language
correction at its default) and joins the observations of a row into one line,
left to right. A row follows the receipt's tilt, learnt from the rows above,
so the amount at the right edge of a curled receipt meets its own name. A
real receipt is regenerated from its photograph the same way, then masked by
hand as above. The recorded text depends on the macOS version: after
regenerating it, check that `*.rule.json` still describes what the parser
must read from it.

## How the tests find these files

The shared-logic tests read the directory named by the environment variable
`MONEGING_FIXTURES` (set by `acceptance/shared/build.gradle.kts`), else the
nearest `fixtures` or `acceptance/fixtures` above the working directory. The
iOS UI tests pass the app the absolute path of this directory in the launch
argument `-UITestScannerFixtures` (`acceptance/ios/XCUIApplication+Scanning.swift`).

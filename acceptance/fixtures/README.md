# acceptance/fixtures

Material shared by the shared-logic tests (`AC-B-5xx`) and the UI tests
(`AC-F-501`, `AC-F-504`, `AC-E-501`). Two receipts are drawn and fictional;
seven are the recognised text of real receipts, with what identifies a person
or a payment masked (below): five read on a Mac, and two of the same receipts
read again on an iPhone, whose Vision reads them differently. The pictures of
the real receipts are not kept here.

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
  mcdonalds.txt                                   a fast-food order of sets with a discount on the whole receipt
  mcdonalds-device.txt                            the same McDonald's receipt, read on an iPhone
  seven-eleven-shiba-device.txt                   the same seven-eleven-shiba receipt, read on an iPhone
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

An item with an amount below zero is a **discount item**, a discount on the
whole receipt (`PRODUCT.md` §3, Line item): `{ "name": "ディスカウント",
"amount": -250, ... }`. The negative amount is its only mark; every other item
is at least 1 yen. A discount taken off one item is not an item of its own: it
is already in that item's amount.

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
| `マクドナルド`    | `マクドナルド`                        |

A spelling is found in the text with its lines joined by spaces, letters
compared without case (the マルエツ プチ receipt prints its logo as the lines
`maruetsu` and `petit`).

### Fields

- store: the name of the chain whose spelling appears first in the text; when
  none appears, the first line.
- date: the first `yyyy/mm/dd` or `yyyy年m月d日` in the text, as `yyyy-mm-dd`.
  The slashed form has a two-digit month and day; the `年月日` form has one or
  two digits for each (`2026年09月28日`, `2026年10月1日`).
- total: the amount on the first line that starts with `合計` (`合計 ¥5,315`,
  `合計金額 ¥2,330`).
- category: none (`null`) for every item; the parser does not classify. A
  discount item is therefore without a category too.
- confidence: every field and item it read has the constant 0.7, the added
  `消費税` item too.

### Items

The item lines are those after the date line and before the first line that
ends them. A line ends them when it starts, after an optional `（` or `(`, with
a word of the receipt's summary — `小計`, `合計`, `商品代金` or `値引合計`
(`小計 ¥4,922`, `（商品代金 ¥2,178）`, and `商品代金 ¥2,178）` as a phone
reads it, without its opening parenthesis) — or when it starts with `（` or
`(` and does not end with an amount (a summary such as
`（ 8%外税対象額 ¥5,235）`, whose last token is `¥5,235）`). A line that starts
with a parenthesis and ends with an amount is an item line (a set,
`（ジャガペッパーツキミレセット）＊1060 （1コ） ¥1,060`).

A line that names the date, the register or the time is never an item, whatever
its last token: one containing a date in a form read above, `レジ` followed by
`No`, `NO`, `#` or a digit (`00レジNO 00`, `レジ #0`, `レジ0012`; not
`レジ袋`), or a time `h:mm` or `hh:mm` (`19:00`, `（木）19:00`).

A **price** is the last space-separated token of a line when it has the shape
of a number of yen: an optional reduced-tax mark `*` or `＊`, an optional `¥`
or `￥`, an optional `-`, digits with a comma every three from the right
(`3,280`; `6501` is not a price), and an optional `※`. `50%`, `15:48`,
`登録No0000`, `1コ` and `1］` are not prices. A line that ends with a lone `¥`
continues on the next line: the two are read as one line joined by a space
(`■ JUICY巨峰ミルクティー JUICY ¥` and `Kyoho Grape Milk Tea 1,010`), and its
price counts as printed with `¥`.

A receipt **prints its prices with `¥`** when, among the item lines that end
with a price (the item lines found with every price taken as an amount, the
date, register and time lines left out), more end with a price printed with
`¥` or `￥` than without; a tie is not. `ディスカウント ¥250` and a quantity
line count like any other line. Then a price printed with neither `¥`/`￥` nor
`-` is not an amount: what a phone reads as `11` in place of a count
(`マックフライポテトレ 11`) is not taken for yen. Otherwise, and for a price
with `¥` or `-`, an **amount** is a price. Of the recorded texts,
`seven-eleven.txt`, `corner-deli.txt`, `life.txt` (its `-198` stays an amount),
`ubereats-gongcha.txt` and the two McDonald's texts print their prices with
`¥`; `maruetsu-petit.txt` and the two seven-eleven-shiba texts (`*648`, `578`)
do not.

A **discount line** is one whose text contains `ディスカウント`, `値引` or
`割引`. Its printed sign tells what it takes off: an amount printed without
`-` (`ディスカウント ¥250`) is a discount on the whole receipt; an amount
printed with `-` (`値引額 -50`, `★割引（20%） -120`) is a discount on the item
above, and so is a discount line without an amount above a quantity line with
one (`シール割引 50%` above `2コX単-99 -198`). Whether the line above has an
amount does not matter.

Each item line is, in this order:

1. a **quantity line** — it starts with a quantity and a unit price
   (`2コ✕単178 ¥356`, `2コX単-99 -198`, `@159x 3 *477`, `＠159× 3 *477`;
   `@` or `＠`, and `X`, `x`, `✕`, `×`):
   its amount is the amount of the line without an amount right above it (an
   item's name, `キリンファイアワンデイブラック600ml`), and when that line is a
   discount (`シール割引 50%`), the discount's.
2. a **receipt discount line** — a discount line whose amount is printed
   without `-` (`ディスカウント ¥250`): a discount on the whole receipt,
   wherever it stands among the item lines. It becomes a discount item of its
   own, after the items, with its amount made negative and its text before the
   amount as its name (`ディスカウント` −250). It is not added to any item.
3. any other **discount line** — its amount printed with `-` (`値引額 -50`,
   `★割引（20%） -120`), or without an amount above a quantity line
   (`シール割引 50%`): its amount, already below zero, is added to the item
   above, the discount's own amount or that of the quantity line below it
   (`-198`).
4. an **option line** — it starts with `+` (`+ LARGE RICE ¥150`), or the text
   before its amount contains `※` (`氷Ice※通常 ¥120`): its amount is added to
   the item above. It is not an item.
5. an **item** — any other line with an amount: its amount and its name. A
   line that starts with `（` or `(` is a set or a single product printed in
   parentheses (`（マックフライポテトL） * 440 （ココ） ¥440`).
6. any other line without an amount — the name of the item when a quantity
   line follows it, else not read (`ICED/Mサイズ`, `★売変@499 →@199`). The
   lines below a set that give a name and only a count (`マックフライポテトL
   1コ`, `コカコーラ 1］`, and `マックフライポテトレ 11` in a receipt that
   prints its prices with `¥`) are its contents: they are not read, and they
   are not items.

An item's **name** is, for a line that starts with `（` or `(`, the text
inside its first pair of parentheses, up to the first `）` or `)`
(`（ジャガペッパーツキミレセット）＊1060 （1コ） ¥1,060` is named
`ジャガペッパーツキミレセット`); the price and count after it (`＊1060`,
`*440`, `（1コ）`, and misread as `（12）` or `（1］）`) are dropped, and the
set's amount is the line's last token (`¥1,060`). For any other line it is the text before the amount,
with, from its start, a delivery order's check box dropped (in a receipt whose
first line is `Uber Eats`, a leading `ロ`, `■` or `□` and the space after it),
then the reduced-tax mark `*` or `＊`, then an item code of three digits and
the space after it (`651 アキタコマチ5`, `344野菜炒め`). The rest is kept as
it was recognised, spaces and misreadings included (`A 豚こまぎれ`,
`ヤマキめんつゆ50（`, `ジャガペッパーツキミレセット` for `…ツキミLセット`):
the parser does not correct the text.

### Added tax

When the text shows that the items exclude tax — a line containing `外税`,
`外8%`, `外10%` or `税抜` — the parser adds, after the items and the discount
items, one item `消費税` of the total minus the items' sum, without a
category, so that the items add up to the total. Tax included in the prices
(`内消費税等`, `内消費税`) adds nothing.

## The real receipts

Each `.txt` of a real receipt is what `ocr.swift` read from its photograph,
then masked; a `-device.txt` is what the app's scan read from the same
receipt on an iPhone 14 Pro (Vision on the device, copied from the app's
development build), masked the same way. The device and the Mac read the same
paper differently (`（12）` for `（1コ）`, `11` for `1コ`, the date and the
register on two lines, `*440` for `* 440`, `＠159×` for `@159x`,
`商品代金 ¥2,178）` without its opening parenthesis, a stray `子` before the
chain's name); the draft each must give has the store, date, total and item
amounts of its Mac reading, with the item names as the device read them. Masked are, digit by digit: register (`レジ`, `登録機`) numbers
and the number printed before `レジ` (`00レジNO 00`), transaction, slip,
order, receipt and terminal numbers (`登録No`, `取引通番`, `端末識別番号`,
`伝票番号`, `支払伝票番号`, `オーダー明細ID`, `レシートNo`, the `#…` and
`No.…` numbers, the order's call number printed large at the foot of a
fast-food receipt), the staff member's number (`責`, `No…：応援者`), campaign
serial numbers, the orderer's name and the order number. A masked digit
becomes `0`, a masked letter or character of a name `X` (`X0000`, `X・XX`,
`責：00000000XX`); punctuation stays, so every masked value keeps its length.
Kept are the store name, its address and telephone, the business registration
number (`登録番号`, `事業者登録番号`, the store's, printed on every receipt),
the store number, dates and times, item names, amounts, totals, tax and the
name of the payment service (`PayPay`). The text is not otherwise corrected:
misreadings stay as recognised.

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
hand as above. A `-device.txt` is not regenerated by `ocr.swift`: it is
scanned again on the device. The recorded text depends on the macOS version: after
regenerating it, check that `*.rule.json` still describes what the parser
must read from it.

## How the tests find these files

The shared-logic tests read the directory named by the environment variable
`MONEGING_FIXTURES` (set by `acceptance/shared/build.gradle.kts`), else the
nearest `fixtures` or `acceptance/fixtures` above the working directory. The
iOS UI tests pass the app the absolute path of this directory in the launch
argument `-UITestScannerFixtures` (`acceptance/ios/XCUIApplication+Scanning.swift`).

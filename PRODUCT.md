# PRODUCT.md — Moneging

A household expense tracker for one person on one device. Sharing a ledger
with a household is planned for v2 (§2).

This document is the specification an autonomous agent works from. It states
what the product does and how each claim is checked. It does not say how to
build it: architecture and code structure belong to whoever implements it,
recorded in `DECISIONS.md`. Where a choice is already fixed — the platforms,
the on-device datastore, the absence of any server in v1 — it is stated here
because the acceptance criteria depend on it.

The document is in English because the repository is. The product's own user
interface is in Japanese.

## 1. Purpose

People give up on tracking spending because entering it is tedious and because
the numbers arrive too late to change anything. This product attacks both: a
receipt photo or a tap of a transit IC card becomes a draft entry without
typing, and the user hears that they are spending too fast while the month can
still be steered.

In v1 the user is one person on one device. A user may keep several ledgers.
A household of a few people sharing one ledger is planned for v2.

## 2. Scope

### In scope (v1)

- Native applications: iOS (SwiftUI) and Android (Jetpack Compose), their
  logic shared through Kotlin Multiplatform (`clients/kmp`).
- Local only, and free: every record lives in a database on the device; the
  app works fully offline; there is no sign-in, no server and no network call.
- Several ledgers on one device.
- Expenses and income, entered by hand, from a receipt scan or from a transit
  IC card's history, optionally split into line items.
- Recurring monthly entries.
- Receipt photographs: kept with the ledger on the device, listed, deleted.
- Receipt scanning on the device, through the OS document scanner and on-device
  text recognition, producing an editable draft.
- Monthly budgets per category, with the leftover carried over or saved.
- Learned spending pace per category, and a notification — in the app's list
  and as a local OS notification — when a category runs ahead of it.
- Reports: monthly totals by category, a day-by-day total, a twelve-month trend.
- A calendar view of daily spending, including days with no spending at all.
- A look chosen on the device: five styles, six theme colours, light or dark,
  and the NMD badge.
- A home-screen widget showing this month's remaining budget and a quick way
  to start an entry.
- Reading a transit IC card (Suica and the like) over NFC and importing its
  usage history as drafts, never importing the same history twice.
- Backup: the app's data is included in the OS device backup (iCloud backup,
  Android Auto Backup), and the whole database is exported to and imported from
  one file through the OS share sheet and file picker, so a user can move
  between devices and between iOS and Android.

### Planned (paid, v2)

Not built in v1; listed so v1 does not close the door on them.

- Household sharing: ledgers shared by invitation, and sync between devices,
  through a server.
- Sign-in, needed for sharing. The App Store requires Sign in with Apple (or an
  equivalent) whenever a third-party login such as Google is offered.
- Connection to an external LLM.
- In-app purchase through the App Store and Google Play, with the purchase
  receipt verified on the server.

### Out of scope

- Passwords.
- Any web application, and any platform other than iOS and Android.
- Currencies other than Japanese yen.
- Bank, card or e-money account synchronisation. Reading a transit IC card's
  own history over NFC is in scope; syncing with an online account is not.
- Payment-method breakdowns.
- CSV or any other export for analysis. The whole-database backup file is the
  only export.
- Tax or accounting output.
- Email notifications, and push notifications sent from a server.
- Payments, or moving real money. (The v2 in-app purchase of the product itself
  is the only payment planned.)

## 3. Domain

Money is an integer count of yen. There is no fractional yen anywhere in the
product, and no floating-point type may hold an amount.

| Concept | Meaning and invariants |
| --- | --- |
| **User** | The person using the app on a device. v1 has no accounts: nobody signs in and nothing identifies the user outside the device. The user carries their own look: a style, a theme colour, a brightness and an NMD badge (see §5 見た目). The look is kept on the device, identical in every ledger. A user who never chose has やさしい・あたたかい, テラコッタ, the device's brightness and にっこり硬貨. |
| **Ledger** | A book of money on the device. Every transaction, budget, photo and category belongs to exactly one ledger. A device may hold several ledgers, and the user always acts within one of them. |
| **Category** | A bucket for spending, scoped to a ledger. The default set is 食費, 日用品, 住居, 水道光熱費, 交通費, 通信費, 医療, 教育, 娯楽, 交際費, 衣服, その他. A ledger may add, rename and archive its own; an archived category keeps its history but takes no new transactions. |
| **Transaction** | One movement of money on one date: a direction (expense or income), an amount, a category, an optional memo, an optional store name and an optional link to a photo. The amount is at least 1 yen. The date is a calendar date, not an instant. The store name is filled from a confirmed draft and may be set or changed by hand. A transaction confirmed from a draft whose items did not add up is marked needs-review (`needsReview`); the mark is cleared when a user marks it reviewed, or by any change that leaves it with no item named exactly `差額`, and it is never set by hand. OPEN: takamai also recorded who recorded each transaction; whether v1 keeps an author or device identifier for v2 sharing. |
| **Line item** | A transaction may instead be split into several items, each with its own amount, category and optional item name. When a transaction has items, its amount equals the sum of its items, and each item is at least 1 yen. An item name is filled from a confirmed draft and may be set or changed by hand. |
| **Recurring rule** | A transaction that repeats monthly on a day of the month, between a start month and an optional end month. Materialising a month creates its transactions exactly once, whatever the number of attempts. |
| **Photo** | An image belonging to a ledger. Its bytes live in the app's private storage on the device; its record carries the content type, the size and the capture instant. Deleting a photo removes the stored bytes as well as the record. A photo referenced by a transaction cannot be deleted until the reference is removed. |
| **Scanner** | A reader of receipts, entirely on the device: the OS document scanner captures the receipt (VisionKit on iOS, ML Kit on Android) and on-device text recognition (Vision on iOS, ML Kit on Android) reads it. Both platforms answer the same question — store name, date, total, line items, each with the scanner's confidence — so the product never branches on which one is in use. A scan costs nothing per use, so there is no scan quota. |
| **Scan job** | The reading of one photo. Moves `queued → running → succeeded` or `→ failed`, never backwards. A failed job carries a human-readable reason. A job left running longer than its deadline, or cut off because the app ended, becomes failed. OPEN: takamai's scan was asynchronous on a server; whether v1 keeps reading in the background with the `読み取り` list (as specified below), or opens the draft editor directly after each scan. |
| **Draft** | The result of a succeeded scan: a proposed store name, date, total and line items (each with a name, an amount and optionally a category), each field carrying the scanner's confidence. A succeeded scan always keeps the items it read, even when they do not add up to the total it read. A draft is not a transaction until a user confirms it, and any field may be corrected first, its category and items included. Confirming a draft with items creates one expense with the draft's store and date, linked to the photo, and one line item per draft item; an item without a category is confirmed into その他. When the items add up to the total, the expense is the total. When they do not, confirming is refused unless the user accepts the mismatch (`acceptMismatch`), and then the expense is marked needs-review: below the total, the expense is the total and gains, after the items, one item `差額` of the difference, in the items' category when every item names the same active one, else その他; above the total, the expense is the items' sum. A user may instead record the total alone by removing the items: a draft with no items confirms into one unsplit expense of its total in its category, or その他 when it has none, with its store and date, linked to the photo. A draft may also be discarded. Either way it is gone afterwards. A draft imported from an IC card has no photo and no items (see IC card history). |
| **IC card history** | A transit IC card (Suica and other FeliCa cards) read over NFC (Core NFC on iOS, NFC-F on Android). The card holds a short history of its latest uses, each with a date and the balance left after it; an entry's amount is the change in balance from the entry before it. Reading a card turns every entry not yet imported into a draft expense of that amount on that date, with no photo. An entry is identified by the card's identifier and the entry's sequence number, and once imported — whether its draft is later confirmed or discarded — it is never imported again. OPEN: what becomes of a charge (a rise in balance): income, a transfer, or skipped. OPEN: the category an imported draft proposes (交通費 for a fare, none for a purchase, or none at all), and whether a store name is proposed (station names need a station table). OPEN: the oldest entry on the card, whose amount cannot be computed from a previous balance. |
| **Budget** | For one ledger and optionally one category: a planned amount, set from a month on and continuing into every later month until another amount is set or the budget is removed from a month on. A month has at most one budget per category and at most one whole-month budget. Remaining is the budget, plus whatever was carried into it, minus the spending recorded against it; it may be negative. A category budget counts its category's expenses, split items included; the whole-month budget counts every expense. |
| **Carry-over policy** | What happens to a month's leftover when the month closes: `carry` moves each budget's leftover into the same budget next month, `save` moves it to savings — the whole-month budget's leftover when there is one, otherwise the category budgets' leftovers added up. A negative leftover moves nothing. Chosen per ledger (`carry` until changed), changeable, and applied once per month. A month closes only by the user's request, only after it has ended (in Asia/Tokyo), and only when every earlier month that has a budget is closed; a closed month's budgets are final. |
| **Savings** | A per-ledger running balance that only grows by closing a month under the `save` policy, with each contribution recorded against its month. |
| **Pace** | For a ledger, a category and a day: the spending expected by that day, learned from how the category was spent in the three calendar months before the day's month, a month with no spending counting as zero. For each of those months, what the category had spent up to and including the same day of the month is taken (the whole month when the month is shorter), and the expectation is their average, rounded down to a whole yen. A category paid at month end, such as rent, therefore expects nothing until its day. A category with no spending in any of the three months has no expectation (not 0). The learned monthly amount, shown for context, is the average of the three months' whole spending, rounded down. Spending is expenses only, split items counted in their own category; income never counts. A category is _ahead of pace_ when spending to date exceeds the expectation by more than 20%, computed in integers (spent × 10 > expected × 12), and only when the expectation is at least 1 yen: an expectation of 0 is never exceeded. |
| **Notification** | A message in a ledger: its kind, its text, the instant it was raised, and whether it has been read. Notifications are listed in the product, and each one is also posted, when it is raised, as a local OS notification on the device, if the user has allowed notifications; nothing is sent off the device. The one kind is a pace alert: when a category goes ahead of pace in a month, a notification naming it is raised, once when it first goes ahead and again only after an evaluation has found it back within pace, however often pace is evaluated. This is kept per ledger, category and month. An archived category never raises one. Pace is evaluated for the ledger's today in Asia/Tokyo after an expense is written and whenever the notification list is opened, and for any date up to today on request; a later date is refused. The text is Japanese, composed by the product when the notification is raised: `食費のペースが速めです（2月15日までに19,000円・目安15,000円）`. Marking one read is idempotent, and all of them may be marked read at once. |
| **Backup file** | One file holding a device's whole database — every ledger and every record in it, tombstones included — in a format that is the same on iOS and Android. OPEN: whether photo bytes are in the file. OPEN: whether importing a file replaces everything on the device or merges with it by identifier. |

## 4. API contract

v1 has no API: the app makes no network request, and every operation is a call
into the shared Kotlin Multiplatform logic on the device.

The v2 server API will be contract-first: a spec under `contracts/openapi` is
the source of truth, the server interface and the clients are generated from
it, and the spec changes before the code does.

## 5. User interface

Japanese, native — SwiftUI on iOS, Jetpack Compose on Android — and usable
one-handed on a phone. The app is named `Moneging` on the home screen. The
ledger in view is chosen with a header control, and the app reopens on the
ledger last in view.

Tabs: **ホーム**, **カレンダー**, **グラフ**, **設定**. ホーム, カレンダー and
グラフ show the same month, the current month until a header control changes
it; the app keeps the month in view when it returns from the background.

- **ホーム** — this month's remaining budget, the total spent, the most recent
  transactions, `記録する` to add one by hand, and the `読み取り` card while
  receipts are being read or drafts wait to be confirmed (see
  レシートの読み取り). The remaining budget is a card (`今月の残り予算` with
  `予算 50,000円`) and a list of the category budgets
  (`食費 残り 11,500円 予算 30,000円`; an overspent one reads `1,500円オーバー`;
  a category spent without a budget shows what was spent). When a month that
  has ended is still open, ホーム offers to close it (`1月を締める`) and says
  what the policy will do.
- **カレンダー** — a month grid. Each day shows its total. A past day with no
  spending shows the **NMD** (No Money Day) badge, an illustrated icon; today,
  future days and days before the ledger was created never show it. A day is
  named by its date and total (`2月3日 4,000円`, or `2月4日 NMD`). Tapping a day
  lists that day's transactions.
- **グラフ** — spending by category for the month as a share, and the last
  twelve months as a trend. Every chart shows its figures as text beside it: the
  share as a list of category, amount and percentage (`食費 3,000円 50%`, whole
  percentages that add up to 100%), the trend as a list of month and amount
  (`2025年4月 1,000円`). Income is never charted as spending.
- **設定** — the user's look (`見た目`), ledgers, categories, budgets and
  carry-over policy, and backup.
  The `予算` section lists the budgets in force from the current month;
  `予算を追加` opens a form (`カテゴリ` or the whole month, `金額`, `保存`), a
  listed budget opens it to change or remove it; `繰越の方法` chooses
  `翌月に繰り越す` or `貯金する`; `貯金` shows the balance and its months; the
  oldest open month can be closed there too.

Recording by hand: `記録する` opens a form — `日付`, `支出` or `収入`, `金額`,
`カテゴリ`, `店名`, `メモ` — saved with `保存`. A listed transaction opens the
same form to change it or `削除` it. The home tab lists the month's
transactions, newest first, under the month's `支出` and `収入` totals; a
transaction with a store shows it. Amounts are shown as `1,200円`.

Below `見た目`, the 設定 tab has two sections. `カテゴリ` lists the ledger's
categories in order, an archived one marked `アーカイブ済み`; `新しいカテゴリ`
with `追加` adds one at the end; each active category offers `名前を変更` and `アーカイブ`,
which asks for confirmation first.
An archived category is not offered when recording. `定期支出` lists the
ledger's recurring rules as `毎月25日 80,000円 住居`; `追加` opens a form —
`支出` or `収入`, `金額`, `カテゴリ`, `毎月` … `日`, `開始月`, `終了月`
(optional), `メモ` — saved with `保存`; a listed rule opens the same form to
change it or `削除` it; `今月分を記録` materialises the current month.

**見た目** — 設定 opens with the section `見た目`, above every other section:
the user's own look, in four groups of buttons, the chosen one in each group
pressed. `スタイル` offers やさしい・あたたかい, すっきり・ミニマル,
落ち着いた・大人っぽい, 元気・カラフル and かわいい, each with a small sample;
`テーマカラー` offers テラコッタ, ローズ, ラベンダー, ソーダ, セージ and 墨 as
named swatches; `明るさ` offers `端末に合わせる` (the device's light or dark,
followed as it changes), `ライト` and `ダーク`; `NMDバッジ` offers にっこり硬貨,
ふたば and きらり星, the badge the calendar shows. A choice applies at once, with
no save button, and is saved on the device, so it holds in every ledger. A save
that fails puts the previous look back and says so
(`見た目を保存できませんでした`). The app opens in the saved look from its first
frame. OPEN: takamai defines the five styles and six colours as web styles
(fonts, shapes, CSS colours); how each maps onto SwiftUI and Compose theming,
whether the widget follows the look, and whether Android's dynamic colour is
ignored.

Every screen has a loading state, an empty state and an error state; a failed
operation is always shown to the user, never swallowed.

**はじめに** — When the device holds no ledger, as on first launch, the user
sees an introduction instead of the tabs: what the product does (record
spending, read a receipt, watch the budget), and one field for the name of the
first ledger, filled in with `家計`. Creating it opens the home tab. It is
shown again only if the device ever holds no ledger again.

**レシートの読み取り** — A round camera button, `レシートを読み取る`, sits
beside the tab bar on every screen. It opens a sheet with `写真を撮る` (the OS
document scanner) and `写真を選ぶ` (one or several photos at once from the
photo library). Every photo given is kept as it is and its scan started; the
sheet then closes with a toast naming how many were sent
(`2枚の読み取りを受け付けました`). Nothing waits for a scan: the user may send
more at once, record by hand or leave the app. While a scan is queued or
running or a draft waits, ホーム shows the `読み取り` card
(`読み取り中 1件・確認待ち 2件`), read from the database so reopening the app
finds it again; it opens the list of receipts. There a waiting draft shows its
store and total (`セブン-イレブン 1,180円`) and opens the draft editor; a scan in
flight says so; a failed scan shows its reason and offers `手で記録する` (the
record form, linked to the photo) and `もう一度読み取る`. The draft editor,
`読み取り結果の確認`, shows the photo and every field editable: `店名`, `日付`,
`合計`, and the items as rows of `品名`, `金額` and `カテゴリ`, each removable,
with `明細を追加`. A draft with no items shows instead one `カテゴリ` select
for the whole expense, left empty for その他. A field whose confidence is below
0.6 is marked `要確認` in its label or its description. OPEN: whether
`写真を選ぶ` (reading photos from the library rather than the document
scanner) stays in v1, and whether one document-scanner session of several
pages means several receipts.

While a draft has items whose sum differs from `合計`, the editor warns, as an
alert,
`明細の合計 830円 が合計 980円 と 150円 合いません。写真を見て直すか、下のボタンで整えてください。`
(the items' sum, the total and the difference between them), the items' sum
line turns to the warning colour, and two buttons follow. `差額を明細に足す`,
shown only when the sum is below the total, adds an item `差額` of the
difference, in the items' category when every item names the same one, else
その他. `合計だけで記録` removes every item and shows the whole-expense
`カテゴリ`. `確定` saves the corrections and confirms the draft. While the
items do not add up it first asks, in an alert dialog titled
`合計額が合いませんがよろしいですか？`, which names the three amounts
(`明細の合計 830円 と合計 980円 が 150円 違います。このまま記録すると、`) and
then says, when the sum is below the total,
`差額 150円 を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。`,
or, when it is above,
`明細の合計 1,030円 で記録し、要確認の印を付けます。`. `戻って直す` returns
to the editor; `このまま記録する` saves the corrections and confirms the draft
accepting the mismatch. `破棄` discards it after asking. The photo stays with
the confirmed record: its form shows it as `レシートの写真を見る`.

**要確認** — A record confirmed with its mismatch accepted is marked
`要確認` until a user resolves it. While any record of the ledger is marked,
ホーム shows the card `要確認 N件` with `明細が合計と合わないまま記録したもの`,
and never with N of 0. The card opens the sheet `要確認の記録`
(`月をまたいで、印が付いている記録をすべて表示します`): every marked record of
the ledger, whatever its month, newest first, in the same rows as ホーム. A
marked record's row carries a `要確認` chip before its category, on ホーム, in
カレンダー's day list and in the sheet. Its form, `記録を編集`, says as an
alert
`要確認：読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。`
(the amount of its `差額` item; without one,
`要確認：読み取った明細が合計と合わなかったため写真を見て直してください。`).
Its `差額` row is marked with the warning colour. A text button
`このままで確認済みにする` clears the mark, with the hint
`「差額」をなくして保存するか「確認済みにする」を押すと、要確認の印が消えます`;
saving the record without its `差額` item clears it too.

**お知らせ** — A bell, `お知らせ`, sits in the header on every screen, at the
top right beside the per-screen slot (the month chip on ホーム, カレンダー and
グラフ; 設定 has none, and the bell stays). While any notification is unread it
wears a badge with the unread count, which its name carries too
(`お知らせ（未読2件）`); with none unread it is named `お知らせ` alone. The
count is read from the database, again whenever the ledger changes and when the
app returns to the foreground. The bell opens the list `お知らせ`: the
notifications of the ledger in view, newest first, each a control showing its
text and when it was raised (`2月15日 9:12`). An unread one is marked with a dot
and bold text and says `未読` to a screen reader; a read one is dimmed. Tapping
a notification marks it read and leaves the list open; `すべて既読` marks every
one read. With no notifications the list reads `お知らせはありません`.

A pace alert is also posted as a local OS notification carrying the same text.
Tapping it opens the app. When the user has not allowed notifications, alerts
still appear in the list and nothing else changes. OPEN: when the app asks for
permission to post notifications, and whether tapping one opens `お知らせ` of
its ledger.

**ウィジェット** — A home-screen widget (WidgetKit on iOS, Glance or an App
Widget on Android) shows this month's remaining budget as ホーム's card does
(`今月の残り予算` `28,500円`), and `記録する`, which opens the app on the
record form. It shows what the database holds, updated whenever a transaction
or a budget changes. OPEN: which ledger the widget shows when the device holds
several (the one last in view, or one chosen per widget), and what it shows
when the month has no whole-month budget.

**交通系ICカード** — On a device with NFC, `ICカードを読み取る` asks the user
to hold the card to the phone, reads its history and imports every entry not
yet imported as a draft, which waits in the `読み取り` list like a receipt's
and opens the same editor, without a photo. A toast names how many were
imported (`3件の履歴を取り込みました`), or says `新しい履歴はありません`. A
device without NFC does not offer it. OPEN: where `ICカードを読み取る` sits
(the `レシートを読み取る` sheet, ホーム or 設定).

**バックアップ** — 設定's section `バックアップ` offers `データを書き出す`,
which writes the backup file and hands it to the OS share sheet, and
`データを読み込む`, which opens the OS file picker and imports the chosen file
after asking. The same file imports on iOS and on Android. A file that is not a
backup file is refused with `このファイルは読み込めません`, and nothing changes.
Besides this, the app's data is included in the OS device backup.

## 6. Non-functional requirements

- **Money.** Integer yen throughout, in storage, in the shared logic and in the
  UI.
- **Local only.** v1 makes no network request of its own; every feature works
  with the device offline, from first launch. OPEN: ML Kit's document scanner
  is delivered through Google Play services and may download its module on
  first use; whether that is acceptable, or a bundled alternative is required.
- **Durability.** One database on the device holds every record, reached
  through the shared Kotlin Multiplatform logic. Photo bytes live in the app's
  private storage. Schema changes are migrations in the repository, applied on
  start. Nothing leaves the device except through the OS device backup and an
  exported backup file.
- **Sync-ready data.** Every record carries a UUID identifier generated on the
  device, and the instants it was created and last updated. Deleting a record
  leaves a tombstone — the record marked deleted, with the instant — which the
  product never shows or counts. This lets v2 sync ledgers without changing
  identifiers.
- **Device backup.** The database and the photos are included in the iCloud
  backup on iOS and in Android Auto Backup and device-to-device transfer.
  OPEN: Android Auto Backup keeps at most 25 MB per app; what is left out when
  the data is larger.
- **Isolation.** No operation in one ledger may read or write another ledger's
  data. This is proven by tests, not by review.
- **Asynchrony.** Scanning never blocks the interface. A scan that crashes
  leaves its job `failed`, never `running` forever.
- **NFC.** iOS reads FeliCa cards through Core NFC, which needs the NFC
  entitlement and the cards' system codes declared by the app; Android reads
  them as NFC-F.
- **Determinism in tests.** Time, the scanner, the IC card reader and the OS
  notification poster are injected, so tests never wait for a clock, a camera,
  a card or the OS. A scanner that reads a fixture deterministically and a card
  reader that replays a fixture are part of the product.
- **Supply chain.** Every GitHub Actions step is pinned by commit SHA; a movable
  tag anywhere fails the build. The toolchain is pinned in `mise.toml`. OPEN:
  takamai's container-digest, npm three-day and `go.sum` rules do not apply;
  what replaces them for Gradle and Swift package dependencies.
- **Accessibility.** Every control is labelled and reachable with VoiceOver and
  TalkBack.
- **Safe areas.** Every control stays in full view, uncovered, and clear of the
  status bar, the home indicator or gesture bar, the screen's rounded corners
  and, held sideways, the sensor housing or display cutout; so do the corners
  of every dialog, sheet and menu.

## 7. Acceptance criteria

Every criterion has one test that carries its identifier, written before the
implementation. The harness runs each one; a criterion whose test does not
exist fails once its stage is open (`quality/stage.txt`). `AC-B` identifiers
name a test of the shared logic in `clients/kmp/sharedLogic`'s `commonTest`,
run on every target. `AC-F` and `AC-E` identifiers appear in the title of a
platform UI test, one on each platform: an XCUITest on iOS and a Compose UI
test on Android. `AC-E` tests drive the built app end to end on a simulator or
emulator. OPEN: whether every `AC-F` and `AC-E` criterion needs a test on both
platforms.

Fixtures shared by the criteria below: the ledger is `家計`, and the clock
reads 2026-02-15 unless a criterion says otherwise.

The criteria of the takamai spec that exist only to test a server, sign-in or multi-user
access move to v2 and keep their identifiers there: AC-B-100 (health),
AC-B-101 to AC-B-103 (sign-in and sessions), AC-B-105 and AC-B-106
(invitations) and AC-F-101 (the sign-in screen). AC-B-502 (upload limits) and
AC-B-507 (scan quota) are dropped: v1 uploads nothing and a scan costs nothing.

### Foundation

| ID       | Criterion                                                                              | Test                        |
| -------- | -------------------------------------------------------------------------------------- | --------------------------- |
| AC-B-104 | A ledger is created and listed.                                                        | `TestCreateLedger`          |
| AC-B-107 | An operation in one ledger cannot read or write another.                               | `TestLedgerIsolation`       |
| AC-B-108 | Every record carries a UUID and its instants, and a deletion leaves a tombstone.       | `TestRecordsAreSyncReady`   |
| AC-F-102 | A first-time user creates a ledger through the introduction.                           | `AC-F-102`                  |
| AC-E-101 | On first launch, offline, the app opens the introduction with no sign-in.              | `AC-E-101`                  |

**AC-B-104** — Given a device with no ledger. When the ledger `家計` is
created, then the ledgers listed are exactly `家計`, with the twelve default
categories.

**AC-B-107** — Given ledgers `A` and `B`, `B` named `花子の家計`, with a
category and a photo in `B`. When, acting within `A`, that category and that
photo are read by their identifiers, then neither is found, and nothing
returned names `花子の家計`. When `B` is read, then it is `花子の家計`,
unchanged.

**AC-B-108** — Given the clock at 2026-02-15 12:00. When a ledger, a category,
a transaction with two line items, a budget and a recurring rule are created,
then each has a UUID identifier and created and updated instants of 12:00.
When the clock moves to 12:05 and the transaction's memo is changed, then its
updated instant is 12:05 and its created instant still 12:00. When it is
deleted, then it is neither found nor listed nor counted in any total, and the
database still holds it, with its items, as a tombstone deleted at 12:05.

**AC-F-102** — Given a device with no ledger. When the app is opened, then the
introduction is shown with the name field holding `家計`. When the name is
changed to `我が家` and the button is pressed, then the ledger `我が家` exists
and the home tab shows it. When the app is relaunched, then the home tab is
shown, not the introduction.

**AC-E-101** — Given the built app, freshly installed, on a device with no
network. When it is launched, then the introduction is shown with no sign-in,
and creating `家計` opens the home tab showing `家計`.

### Recording money

| ID       | Criterion                                                             | Test                                         |
| -------- | --------------------------------------------------------------------- | -------------------------------------------- |
| AC-B-201 | A transaction is created, read, updated and deleted.                  | `TestTransactionLifecycle`                   |
| AC-B-202 | An amount is an integer number of yen and at least one yen.           | `TestAmountIsIntegerYen`                     |
| AC-B-203 | A transaction split into line items has items summing to its amount.  | `TestLineItemsSumToTotal`                    |
| AC-B-204 | Transactions are searched by period, category and text.               | `TestTransactionSearch`                      |
| AC-B-205 | Income is recorded and the month's balance is income minus expense.   | `TestMonthlyBalance`                         |
| AC-B-206 | Materialising a recurring rule for a month is idempotent.             | `TestRecurringMaterialisation`               |
| AC-B-207 | An archived category keeps its history and takes no new transactions. | `TestArchivedCategoryRejectsNewTransactions` |
| AC-B-208 | An operation in one ledger cannot read or write another's transactions. | `TestLedgerIsolationForTransactions`       |
| AC-F-201 | The month's transactions and total are listed.                        | `AC-F-201`                                   |
| AC-F-202 | A transaction is created and edited from the interface.               | `AC-F-202`                                   |
| AC-F-203 | Categories are added, renamed and archived from the interface.        | `AC-F-203`                                   |
| AC-F-204 | Recurring rules are set up and materialised from the interface.       | `AC-F-204`                                   |
| AC-E-201 | A user records an expense and sees it in the month's list and total.  | `AC-E-201`                                   |

**AC-B-201** — Given the category 食費. When an expense of 1,200 yen on
2026-02-10 with memo `ランチ` is created, then it has an id and reads back with
that date, direction, amount, category and memo. When its amount is changed to
1,500 and its memo to `外食`, then it reads back changed and its date and
category are unchanged. When it is deleted, then reading it finds nothing.

**AC-B-202** — Given the category 食費. When a transaction is created with
amount `0` or `-100`, then each is refused as invalid. When the form's amount
text `1.5` or `1200円` is read as an amount, then it is refused as invalid.
When it is created with `1`, then it is accepted and reads back as `1`.

**AC-B-203** — Given a transaction of 3,000 yen with items 1,200 (食費) and
1,800 (日用品). When it is read, then its amount is 3,000 and it has two items.
When the 日用品 item is changed to 1,900, then the change is refused and the
transaction still totals 3,000 with its original items. When it is changed to
1,900 together with the total 3,100, then both change (1,200 + 1,900 = 3,100).

**AC-B-204** — Given four expenses in 2026-02: 1,000 食費 memo `スーパー`,
2,000 食費 memo `外食`, 3,000 交通費 memo `電車`, and 4,000 食費 in 2026-01.
When searched by period 2026-02-01..2026-02-28, then three are returned. When
also by category 食費, then two. When also by text `外`, then one, of 2,000.
When searched by amount 2,000..3,000 in that period, then two.

**AC-B-205** — Given 2026-02 with expenses 1,000 and 2,000 and an income of
5,000. When the month's summary is read, then income is 5,000, expense is 3,000
and the balance is 2,000.

**AC-B-206** — Given a rule of 80,000 yen 住居 on day 25, from 2026-01 with no
end. When 2026-02 is materialised three times, then exactly one transaction of
80,000 exists on 2026-02-25. When a second rule of 3,000 yen 通信費 on day 25
is added and 2026-02 is materialised again, then exactly two materialised
transactions exist on that date, and a manual transaction recorded that day is
untouched.

**AC-B-207** — Given the category 娯楽 with one transaction of 2,500 yen.
When 娯楽 is archived, then the transaction still reads back with category 娯楽
and is counted in 2026-02's expense total, and creating a new transaction with
娯楽 is refused as invalid.

**AC-B-208** — Given ledgers `A` and `B`, and a transaction `t1` of 1,200 yen
in `B`. When, acting within `A`, transactions are listed, and `t1` is read,
updated and deleted by its id, then the list does not hold `t1`, and reading,
updating and deleting each find nothing, and `t1` still exists in `B`
unchanged.

**AC-F-201** — Given today 2026-02-15 and a ledger with an expense of 1,200
食費 memo `ランチ` on 2026-02-10, an expense of 3,000 交通費 on 2026-02-14, an
income of 5,000 on 2026-02-01 and an expense of 800 食費 on 2026-01-31. When the
home tab is opened, then it lists the three February transactions newest first
— `3,000円` 交通費, `1,200円` 食費 `ランチ`, `5,000円` — shows `支出` `4,200円`
and `収入` `5,000円`, and does not list the January one.

**AC-F-202** — Given today 2026-02-15 and a February with no transactions. When
`記録する` is pressed, `金額` `1200`, `カテゴリ` 食費 and `メモ` `ランチ` are
entered and `保存` is pressed, then an expense of 1,200 食費 on 2026-02-15 with
memo `ランチ` is created and the home tab lists `1,200円` and shows `支出`
`1,200円`. When that transaction is opened, `金額` is changed to `1500` and
`保存` is pressed, then it is updated and the list and `支出` show `1,500円`.

**AC-F-203** — Given today 2026-02-15 and a ledger with the default
categories. When the 設定 tab is opened, then the twelve defaults are listed in
order. When `ペット` is entered in `新しいカテゴリ` and `追加` is pressed, then
it is created and listed last. When 娯楽's `名前を変更` sets `趣味`, then it is
renamed and listed as `趣味`. When 趣味's `アーカイブ` is pressed, then it is
listed as `アーカイブ済み` and the `記録する` form does not offer it.

**AC-F-204** — Given today 2026-02-15 and a ledger with no recurring rules.
When `定期支出`'s `追加` is pressed and a rule of `金額` `80000`, `カテゴリ`
住居, `毎月` `25` `日`, `開始月` 2026-01 is saved, then that rule is created and
listed as `毎月25日 80,000円 住居`. When `今月分を記録` is pressed, then
2026-02 is materialised and the home tab lists `80,000円` 住居.

**AC-E-201** — Given the built app, freshly installed. When the user creates
`家計` through the introduction and records an expense of 1,200 食費 with
`記録する`, then the home tab lists `1,200円` 食費 and shows `支出` `1,200円`,
and after the app is terminated and relaunched both are still shown.

### Reporting and calendar

| ID       | Criterion                                                           | Test                      |
| -------- | ------------------------------------------------------------------- | ------------------------- |
| AC-B-301 | A month reports totals by category.                                 | `TestMonthlyReport`       |
| AC-B-302 | A month reports a total for every day, including zero days.         | `TestDailyTotalsForMonth` |
| AC-B-303 | The last twelve months report a total each.                         | `TestTwelveMonthTrend`    |
| AC-F-301 | Monthly totals by category are charted.                             | `AC-F-301`                |
| AC-F-302 | The calendar shows daily totals and an NMD badge on past zero days. | `AC-F-302`                |

**AC-B-301** — Given 2026-02 with 1,000 and 2,000 食費, 3,000 交通費, an expense
of 3,000 split into 1,200 食費 and 1,800 日用品, an income of 5,000 in その他,
and 500 食費 on 2026-01-31 and 700 食費 on 2026-03-01. When the monthly report
is read, then it lists 食費 4,200, 交通費 3,000 and 日用品 1,800 in that order
(largest first), the expense total is 9,000, and income is not counted in any
category (その他 is not listed).

**AC-B-302** — Given 2026-02 (28 days) with 1,500 yen on the 3rd and 2,500 on
the 3rd and 800 on the 10th, an income of 5,000 on the 5th, and 700 on
2026-03-01. When the daily totals are read, then 28 entries are returned in
order, each carrying its date, the 3rd is 4,000, the 10th is 800, and every
other day is 0.

**AC-B-303** — Given expenses of 1,000 in 2025-04, 2,000 in 2026-02 and 400 in
2025-02, and an income of 5,000 in 2026-02. When the trend to 2026-02 is read,
then twelve entries are returned in order from 2025-03 to 2026-02, 2025-04 is
1,000, 2026-02 is 2,000, and the rest are 0.

**AC-F-301** — Given 2026-02 with 1,000 and 2,000 食費, 3,000 交通費 and an
income of 5,000, 1,000 食費 in 2025-04, and today 2026-02-15. When the グラフ
tab is opened, then the month's share lists 食費 `3,000円` `50%` and 交通費
`3,000円` `50%` and nothing else, and the trend lists the twelve months from
`2025年3月` to `2026年2月`, with `2026年2月` `6,000円`, `2025年4月` `1,000円`
and the others `0円`.

**AC-F-302** — Given a ledger created on 2026-02-02, 2026-02 with 4,000 on the
3rd (1,500 食費 スーパー and 2,500 日用品), 800 on the 10th, and nothing on the
1st, the 4th, the 15th and the 20th, with today 2026-02-15. When the カレンダー
tab is opened, then the 3rd shows 4,000 (`2月3日 4,000円`), the 4th shows the NMD
badge (`2月4日 NMD`), and the 1st (before the ledger), the 15th and the 20th do
not. When the 3rd is tapped, then its two transactions are
listed and the 10th's is not.

### Budget and savings

| ID       | Criterion                                                          | Test                         |
| -------- | ------------------------------------------------------------------ | ---------------------------- |
| AC-B-401 | A monthly budget per category reports how much is left.            | `TestBudgetRemaining`        |
| AC-B-402 | Closing a month carries the leftover over, or moves it to savings. | `TestMonthCloseCarryOrSave`  |
| AC-B-403 | Closing the same month twice does not double the leftover.         | `TestMonthCloseIsIdempotent` |
| AC-F-401 | Remaining budget per category is shown.                            | `AC-F-401`                   |

**AC-B-401** — Given a 食費 budget of 30,000 from 2026-02 and spending in
2026-02 of 10,000 食費, 9,000 split into 8,500 食費 and 500 日用品, and 3,000
交通費, an income of 5,000, and 700 食費 on 2026-03-01. When remaining is read
for 2026-02, then 食費 shows a budget of 30,000, spent 18,500 and remaining
11,500, 日用品 shows no budget and spent 500, and 交通費 shows no budget and
spent 3,000, in category order. When it is read for 2026-03, then 食費 still
has a budget of 30,000, spent 700 and remaining 29,300.

**AC-B-402** — Given the policy `carry`, a 食費 budget of 30,000 from 2026-02,
and 18,500 食費 and 3,000 交通費 spent in 2026-02. On 2026-02-15, closing
2026-02 is refused as a conflict (it has not ended). On 2026-03-05, when
2026-02 is closed, then the close reports 11,500 carried into 食費 and nothing
saved, the 2026-03 食費 budget is 41,500 with 11,500 carried in, and savings
are 0. Given the same state with policy `save`, when 2026-02 is closed, then
the 2026-03 食費 budget is 30,000, savings are 11,500, and the contribution is
recorded against 2026-02. Afterwards 2026-02 is reported closed, setting a
budget in it is refused as a conflict, and closing 2026-03 is refused (it has
not ended).

**AC-B-403** — Given the state after AC-B-402 with `carry`. When 2026-02 is
closed twice more, then each close reports the same as the first and the
2026-03 budget is still 41,500. With `save`, closing 2026-02 again leaves
savings at 11,500 in one contribution.

**AC-F-401** — Given today 2026-02-15, a whole-month budget of 50,000 and a
食費 budget of 30,000 from 2026-02, and expenses of 18,500 食費 and 3,000 交通費.
When ホーム opens, then `今月の残り予算` shows `28,500円` with `予算 50,000円`,
`カテゴリの予算` shows 食費 `残り 11,500円` `予算 30,000円` and 交通費
`3,000円` without a budget. When 設定's `予算` adds a 交通費 budget of 5,000
with `予算を追加`, then ホーム shows 交通費 `残り 2,000円` `予算 5,000円`.

### Photos and scanning

| ID       | Criterion                                                             | Test                            |
| -------- | --------------------------------------------------------------------- | ------------------------------- |
| AC-B-501 | A photo is kept, listed and deleted, and its bytes go with it.        | `TestPhotoLifecycle`            |
| AC-B-503 | Starting a scan returns immediately with a job that completes later.  | `TestScanIsAsynchronous`        |
| AC-B-504 | A succeeded scan yields a draft with store, date, total and items.    | `TestScanProducesDraft`         |
| AC-B-505 | A draft is corrected field by field and confirmed into a transaction. | `TestDraftCorrectionAndConfirm` |
| AC-B-506 | A failed scan leaves a reason, and the photo stays usable by hand.    | `TestScanFailureIsRecoverable`  |
| AC-F-501 | A scanned receipt shows its scan progressing, then an editable draft. | `AC-F-501`                      |
| AC-E-501 | A user scans a receipt, corrects the draft and confirms it.           | `AC-E-501`                      |

The fixture scanner reads `acceptance/fixtures/receipts/`, shared by the
shared-logic and UI tests: `seven-eleven.jpg` beside `seven-eleven.json`, its
draft — store `セブン-イレブン`, date 2026-02-14, total 1,180, items おにぎり
380 in 食費 and 弁当 800 without a category (380 + 800 = 1,180), with the
confidences store 0.95, date 0.9, total 0.4, おにぎり 0.9 and 弁当 0.5. Beside
it is `corner-deli.jpg`, whose items do not add up (Receipts that do not add
up). It has no draft for any other image, whose scan fails. In UI tests the
fixture stands in for the OS document scanner and text recognition, handing
the app the fixture image as if it had been scanned. Unless a criterion says
otherwise, the scanner answers at once. OPEN: the fixture scanner replaces text
recognition and the reading of its text into a draft, so no criterion checks
how well a real receipt is read; whether v1 needs one (for example, recognised
text fixtures parsed into drafts).

**AC-B-501** — Given a 12 KiB JPEG (12,288 bytes) kept in the ledger as
`image/jpeg`. When the list is read, then it holds one photo of 12,288 bytes
with content type `image/jpeg`. When its bytes are read, then they are
byte-identical to what was kept. When it is deleted, then the list is empty,
reading its bytes finds nothing, and they are gone from the app's storage.
Given a photo referenced by a transaction, when it is deleted, then the
deletion is refused as a conflict and both the photo and its bytes remain.

**AC-B-503** — Given the fixture scanner set to take 200 ms. When a scan of
`seven-eleven.jpg` is started, then the call returns within 100 ms with a job
in state `queued`. When the job is observed, then it reaches `succeeded`
without ever moving back a state, and its draft id is set.

**AC-B-504** — Given the fixture receipt `seven-eleven.jpg`. When its scan
succeeds, then the draft reads store `セブン-イレブン`, date 2026-02-14, total
1,180, and two items — おにぎり 380 in 食費 and 弁当 800 without a category —
each field and item with the fixture's confidence (0.95, 0.9, 0.4; 0.9, 0.5),
and the ledger's waiting drafts list it with that store, date and total.

**AC-B-505** — Given the draft of AC-B-504. When its store alone is corrected
to `セブンイレブン 新宿店`, then everything else reads back unchanged. When the
second item's amount is corrected to 820 with the total 1,200 (380 + 820 =
1,200), then the draft reads back with those values. When it is confirmed, then
a transaction of 1,200 yen exists on 2026-02-14 with store
`セブンイレブン 新宿店` and two line items — おにぎり 380 in 食費 and 弁当 820 in
その他 — linked to the photo, and the draft is gone: reading or confirming it
again finds nothing. Given another draft of the same photo, when it is
discarded, then it is gone, no draft waits, and 2026-02 still holds only the
one transaction.

**AC-B-506** — Given the fixture scanner set to fail with the reason
`provider unavailable`. When a scan is started and completes, then the job is
`failed` with that reason and no draft, the failed jobs list it, the photo is
still listed, and a transaction may still be created by hand linking to that
photo.

**AC-F-501** — Given today 2026-02-15 and the fixture scanner answering the
draft of AC-B-504 (store `セブン-イレブン` confidence 0.95, date 2026-02-14
confidence 0.9, total 1,180 confidence 0.4; おにぎり 380 食費 confidence 0.9,
弁当 800 without a category confidence 0.5), each scan job moving one state on
at a time. When `レシートを読み取る` is pressed and `写真を撮る` scans one
receipt, then the photo is kept as it is and its scan started, the sheet
closes with `1枚の読み取りを受け付けました`, and `レシートを読み取る` opens the
sheet again at once. ホーム's `読み取り` card shows `読み取り中` and then
`確認待ち 1件`; its list shows `セブン-イレブン` `1,180円`; opening it shows
`読み取り結果の確認` with `店名` `セブン-イレブン`, `合計` marked `要確認` (and
`店名` not), and the items おにぎり and 弁当. When 弁当's `金額` becomes 820 and
`合計` 1,200 and `確定` is pressed, then the draft is saved with those values
(弁当 still without a category) and confirmed, the editor closes, `確認待ち`
disappears, and ホーム lists `1,200円` with `セブン-イレブン` and shows `支出`
`1,200円`.

**AC-E-501** — Given the built app, freshly installed, and the fixture scanner
handing it `seven-eleven.jpg`. When the user creates `家計`, presses
`レシートを読み取る`, scans with `写真を撮る`, waits for `確認待ち 1件`, opens the
draft, corrects `店名` to `セブンイレブン 新宿店`, 弁当's `金額` to 820 and `合計`
to 1,200 and presses `確定`, then ホーム with 2026年2月 in view lists `1,200円`
with `セブンイレブン 新宿店` and shows `支出` `1,200円`.

### Pace and notifications

| ID       | Criterion                                                                             | Test                                 |
| -------- | ------------------------------------------------------------------------------------- | ------------------------------------ |
| AC-B-601 | Pace is learned from previous months, per category.                                   | `TestPaceLearnedFromHistory`         |
| AC-B-602 | A category ahead of pace raises one notification when it first goes ahead in a month. | `TestPaceAlertRaisedOncePerDay`      |
| AC-B-603 | Notifications are listed and marked read.                                             | `TestNotificationsListAndRead`       |
| AC-B-604 | A raised notification is posted once as a local OS notification.                      | `TestPaceAlertPostsLocalNotification` |
| AC-F-601 | Notifications are shown and can be marked read.                                       | `AC-F-601`                           |

**AC-B-601** — Given, in each of 2025-11, 2025-12 and 2026-01, 食費 spending
of 15,000 on the 10th and 15,000 on the 20th (January's 10th is an expense of
20,000 split into 15,000 食費 and 5,000 日用品) and a 住居 payment of 80,000 on
the 25th; an income of 50,000 in 食費 on 2025-12-05; and 3,000 交通費 on
2026-02-03. When the pace for 2026-02-15 is read, then it lists, in category
order: 食費 expecting 15,000 (15,000 spent by the 15th in each month) with a
learned monthly 30,000; 日用品 expecting 1,666 (5,000 ÷ 3, rounded down) with
1,666; 住居 expecting 0 with 80,000, not ahead; and 交通費, which has no
history, with no expectation and 3,000 spent. The income counts nowhere, and
no other category is listed. When the pace for 2026-02-25 is read, then 食費
expects 30,000 and 住居 80,000.

**AC-B-602** — Given the history of AC-B-601 and 19,000 yen of 食費 spent by
2026-02-15 (12,000 on the 5th and 7,000 on the 9th, recorded on the 9th),
which is more than 20% ahead of the expected 15,000 (19,000 > 15,000 × 1.2 =
18,000). When pace is evaluated for 2026-02-15 twice, then the first
evaluation raises exactly one notification, unread, naming 食費 with the text
`食費のペースが速めです（2月15日までに19,000円・目安15,000円）`, and the second
raises none. When the clock moves to 2026-02-16 and pace is evaluated for that
day, still 19,000 against the expected 15,000, then nothing new is raised. When
the clock moves to 2026-02-20 and pace is evaluated for that day, the expected
is 30,000, whose threshold is 36,000, so the 19,000 spent is back within pace
and nothing new is raised. Given 20,000 yen more of 食費 dated 2026-02-21
(recorded on the 20th), so 39,000 > 36,000, when the clock moves to 2026-02-21
and pace is evaluated for that day, then it raises a second notification,
`食費のペースが速めです（2月21日までに39,000円・目安30,000円）`, listed first.
Evaluating pace for a date after today is refused as invalid.
Given the same history and 16,000 yen spent instead (16,000 ≤ 18,000), when
pace is evaluated for 2026-02-15, then no notification is raised.

**AC-B-603** — Given two notifications, one read. When the list is read, then
both are returned with their state and instant, newest first. When the unread
one is marked read, then the list reports both as read, and marking it again
changes nothing.

**AC-B-604** — Given the scenario of AC-B-602, a fake OS notification poster,
and notifications allowed. When the first evaluation raises its notification,
then the poster receives exactly one local notification with the text
`食費のペースが速めです（2月15日までに19,000円・目安15,000円）`, and the second
evaluation posts nothing. Given notifications not allowed, when the same
notification is raised, then nothing is posted and the notification is still
listed, unread.

**AC-F-601** — Given today 2026-02-15 and two notifications:
`食費のペースが速めです（2月15日までに19,000円・目安15,000円）`, raised on
2026-02-15 at 9:12 and unread, and
`日用品のペースが速めです（2月14日までに6,200円・目安4,800円）`, raised on
2026-02-14 at 20:31 and read (6,200 > 4,800 × 1.2 = 5,760). When ホーム opens,
then the bell `お知らせ` shows 1 unread (`お知らせ（未読1件）`). When it is
opened, then the list `お知らせ` shows both newest first, the unread one marked
`未読` and the read one not. When the unread one is tapped, then it is marked
read, the list stays open, and the badge disappears: the bell is named
`お知らせ` alone.

### Theme

| ID       | Criterion                                                                             | Test       |
| -------- | ------------------------------------------------------------------------------------- | ---------- |
| AC-F-701 | The look is chosen in 設定 › 見た目, saved on the device, and survives a relaunch.     | `AC-F-701` |

**AC-F-701** — Given the default look (やさしい・あたたかい, テラコッタ,
端末に合わせる, にっこり硬貨). When 設定 › 見た目 chooses the style `かわいい` and
the colour `ローズ`, then the interface's primary colour becomes ローズ's, the
choice is saved on the device (`cute` and `rose`, the brightness and the badge
unchanged), and the chosen buttons are pressed. When the app is relaunched,
then the look is still かわいい / ローズ. When `ダーク` is chosen, then the dark
scheme is in use.

### Receipts that do not add up

| ID       | Criterion                                                                                      | Test                         |
| -------- | ---------------------------------------------------------------------------------------------- | ---------------------------- |
| AC-B-508 | A scan whose items do not add up keeps them, and is confirmed only with the mismatch accepted. | `TestMismatchedDraftConfirm` |
| AC-F-502 | The editor warns of items that do not add up, offers to fix them, and asks before recording.   | `AC-F-502`                   |

The fixture scanner also reads `corner-deli.jpg` beside `corner-deli.json`, a
receipt whose items do not add up — store `コーナーデリ`, date 2026-02-13,
total 980, items 唐揚げ弁当 680 and 緑茶 150, both in 食費 (680 + 150 = 830,
not 980; the receipt's `+ LARGE RICE 150` was not read as an item), with the
confidences store 0.9, date 0.9, total 0.85, 唐揚げ弁当 0.8 and 緑茶 0.9. Its
draft keeps the items, as every succeeded scan's does.

**AC-B-508** — Given the fixture receipt `corner-deli.jpg`. When its scan
succeeds, then the draft reads store `コーナーデリ`, date 2026-02-13, total
980 and the items 唐揚げ弁当 680 and 緑茶 150, both in 食費, with the
fixture's confidences (0.9, 0.9, 0.85; 0.8, 0.9) and no draft-level category.
When it is confirmed as it is, then the confirmation is refused as invalid and
the draft is unchanged. When it is confirmed with `acceptMismatch` true, then
one expense of 980 yen exists on 2026-02-13 with store `コーナーデリ`, linked
to the photo, split into 唐揚げ弁当 680, 緑茶 150 and `差額` 150, all in 食費,
with `needsReview` true, and the draft is gone: reading or confirming it again
finds nothing. Given a second draft of the same photo whose items are all
removed (`items` empty), when it is confirmed, then a second expense of 980 yen
exists in その他, with no line items, linked to the photo, with `needsReview`
false, and no draft waits.

**AC-F-502** — Given today 2026-02-15 and the fixture scanner answering the
draft of `corner-deli.jpg` (store `コーナーデリ`, date 2026-02-13, total 980,
items 唐揚げ弁当 680 and 緑茶 150, both 食費). When a receipt is scanned
through `レシートを読み取る` and its draft, listed behind ホーム's `読み取り`
card as `コーナーデリ` `980円`, is opened, then `読み取り結果の確認` shows the
two items and the alert
`明細の合計 830円 が合計 980円 と 150円 合いません。写真を見て直すか、下のボタンで整えてください。`
with `差額を明細に足す` and `合計だけで記録`. When `差額を明細に足す` is
pressed, then a third item `差額` 150 in 食費 follows the two and the warning
goes; when `確定` is pressed, then the draft is saved with the three items and
confirmed without a question and without `acceptMismatch`, the editor closes,
`確認待ち` disappears and ホーム lists `980円` with `コーナーデリ`. Given a new
draft of it, when `合計` becomes 800, then the alert reads
`明細の合計 830円 が合計 800円 と 30円 合いません。写真を見て直すか、下のボタンで整えてください。`
without `差額を明細に足す`, and `確定` opens `合計額が合いませんがよろしいですか？`
saying `明細の合計 830円 で記録し、要確認の印を付けます。`; `戻って直す` closes
it, the editor stays and nothing is confirmed. When `合計` is 980 again and
`確定` is pressed, then the dialog says
`差額 150円 を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。`;
`このまま記録する` saves the total 980 with the two items and confirms with
`acceptMismatch` true, which records 980 split into the two items and `差額`
150, marked needs-review; the editor closes and ホーム lists `980円` with
`コーナーデリ`. Given a new draft of it, when `合計だけで記録` is pressed, then
the items go and the whole-expense `カテゴリ` shows, and `確定` confirms
without a question: the draft is saved with no items and records 980 unsplit,
not marked.

### Needs-review records

| ID       | Criterion                                                                                                   | Test                       |
| -------- | ----------------------------------------------------------------------------------------------------------- | -------------------------- |
| AC-B-509 | Needs-review records are listed across months, cleared by review or by removing 差額, never marked by hand. | `TestNeedsReviewLifecycle` |
| AC-F-503 | Needs-review records show on ホーム, in their list and in their form, and are marked reviewed there.        | `AC-F-503`                 |

**AC-B-509** — Given ledgers `家計` and `実家`. In `家計`, three drafts of
`corner-deli.jpg` are confirmed with `acceptMismatch`: one dated 2026-01-20,
one dated 2026-02-10, and one whose total is corrected to 800, which records
830 (680 + 150, above the total) with the two items and no `差額`; and an
expense of 800 is recorded by hand on 2026-02-14. In `実家`, one draft of it is
confirmed with `acceptMismatch`. When `家計`'s needs-review transactions are
listed, then they are the 830 of 2026-02-13, the 980 of 2026-02-10 and the 980
of 2026-01-20, in that order, each with `needsReview` true; `実家`'s list holds
only its own record. When the hand-recorded expense is updated with
`needsReview` true, then the update is refused as invalid and it stays
unmarked. When the 2026-02-10 record's memo alone is changed, then it stays
marked, since its `差額` remains. When the 2026-01-20 record is updated with
`needsReview` false, then it is unmarked and still 980 with its three items.
When the 2026-02-10 record's `差額` item is deleted with the transaction's new
amount 830, then it reads 830 with the two items, unmarked. Afterwards `家計`'s
list holds only the 830 of 2026-02-13, and `実家`'s still its own record.

**AC-F-503** — Given today 2026-02-15, an expense of 1,150 食費 memo `カフェ`
on 2026-02-14, and two records marked needs-review: 980 on 2026-02-13 at
`コーナーデリ`, split into 唐揚げ弁当 680, 緑茶 150 and `差額` 150 in 食費, and
2,640 on 2026-01-20 at `ドラッグストア みどり`, split into 洗剤 2,000 and
`差額` 640 in 日用品. When ホーム opens, then it shows the card `要確認 2件`
`明細が合計と合わないまま記録したもの`, and its list shows `980円`
`コーナーデリ` with the `要確認` chip and `1,150円` `カフェ` without. When
カレンダー's `2月13日 980円` is tapped, then its row `980円` `コーナーデリ`
carries the chip too. When ホーム's card is pressed, then the sheet
`要確認の記録` lists `980円` `コーナーデリ` and `2,640円` `ドラッグストア みどり`,
in that order, each with the chip. When `コーナーデリ` is opened from it, then
its form `記録を編集` says
`要確認：読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。`,
and when `このままで確認済みにする` is pressed, then `needsReview` false is
saved for it and the alert goes; with the dialogs closed, the card reads
`要確認 1件` and ホーム's `コーナーデリ` row has no chip. When the sheet is
opened again, it lists only `ドラッグストア みどり`, whose form names
`差額 640円`; when it too is marked reviewed, then the card disappears and ホーム
shows no `要確認` at all.

### Widget

| ID       | Criterion                                                                        | Test                             |
| -------- | -------------------------------------------------------------------------------- | -------------------------------- |
| AC-B-801 | The widget's figures are this month's remaining budget, as ホーム shows it.      | `TestWidgetShowsRemainingBudget` |
| AC-F-801 | The widget shows the remaining budget and `記録する` opens the record form.      | `AC-F-801`                       |

**AC-B-801** — Given the budgets and expenses of AC-F-401. When the widget's
content is read, then it is the remaining 28,500 of a budget of 50,000. When
an expense of 1,000 食費 is recorded on 2026-02-15, then the widget's content
is read again as 27,500 and a widget refresh has been requested.

**AC-F-801** — Given the state of AC-F-401 and the widget on the home screen.
When the widget is shown, then it reads `今月の残り予算` `28,500円`. When its
`記録する` is tapped, then the app opens on the `記録する` form. OPEN: XCUITest
cannot easily inspect a WidgetKit widget on the home screen; how this criterion
is tested on iOS.

### Transit IC card

| ID       | Criterion                                                                        | Test                          |
| -------- | -------------------------------------------------------------------------------- | ----------------------------- |
| AC-B-901 | A card's history is imported as draft expenses of the balance changes.           | `TestCardHistoryImport`       |
| AC-B-902 | Reading a card again imports only history not imported before.                   | `TestCardHistoryNotDuplicated` |
| AC-F-901 | Reading a card from the interface imports its history as drafts.                 | `AC-F-901`                    |

The fixture card reader replays `acceptance/fixtures/cards/suica.json`: a card
`0123456789ABCDEF` whose history holds, oldest first, entry 10 with balance
3,000 on 2026-02-09, entry 11 with 2,790 on 2026-02-10, entry 12 with 2,580 on
2026-02-10 and entry 13 with 2,400 on 2026-02-12 — fares of 210 and 210 and a
purchase of 180. (What entry 10 itself becomes is OPEN, see IC card history.)

**AC-B-901** — Given the fixture card. When it is read into `家計`, then three
drafts wait: expenses of 210 on 2026-02-10, 210 on 2026-02-10 and 180 on
2026-02-12, none with a photo. When the first is confirmed, then an expense of
210 exists on 2026-02-10 and two drafts wait.

**AC-B-902** — Given the fixture card read once, one of its drafts confirmed
and one discarded. When the same card is read again, then nothing is imported
and the one remaining draft still waits. Given the card with a new entry 14
with balance 2,190 on 2026-02-14, when it is read, then exactly one draft is
imported, an expense of 210 on 2026-02-14. When the card is read into `実家`,
then `家計`'s drafts are unchanged.

**AC-F-901** — Given today 2026-02-15, a device with NFC, and the fixture card
reader. When `ICカードを読み取る` is pressed and the card is read, then the
toast says `3件の履歴を取り込みました` and ホーム's `読み取り` card shows
`確認待ち 3件`. When the card is read again, then the toast says
`新しい履歴はありません`. Given a device without NFC, `ICカードを読み取る` is not
offered.

### Backup

| ID       | Criterion                                                                           | Test                        |
| -------- | ----------------------------------------------------------------------------------- | --------------------------- |
| AC-B-110 | Exporting and importing the backup file brings back every ledger and record.       | `TestBackupRoundTrip`       |
| AC-B-111 | A file that is not a backup file is refused and changes nothing.                    | `TestBackupRejectsBadFiles` |
| AC-F-110 | The backup file is written through the share sheet and read through the file picker. | `AC-F-110`                |
| AC-E-111 | The app's data is included in the OS device backup.                                 | `AC-E-111`                  |

**AC-B-110** — Given ledgers `家計` and `実家` holding categories, transactions
with line items, a recurring rule, budgets, a closed month with savings, a
waiting draft, a notification, imported IC card history and a tombstone. When
the backup file is written and imported into an empty database, then every
record reads back identical, identifiers and instants included, and reading the
fixture card again imports nothing. The fixture files
`acceptance/fixtures/backup/android.backup` and
`acceptance/fixtures/backup/ios.backup`, one written on each platform from the
same records, both import into those records. OPEN: the result of importing into a database
that already holds data (replace or merge), and whether photos travel in the
file.

**AC-B-111** — Given `家計` with one transaction. When a text file, an empty
file and a truncated backup file are each imported, then each is refused as
invalid and `家計` still holds exactly its one transaction.

**AC-F-110** — Given `家計` with one expense of 1,200 食費. When 設定's
`バックアップ` presses `データを書き出す`, then the OS share sheet opens with
one backup file. When `データを読み込む` is pressed and a text file is chosen,
then `このファイルは読み込めません` is shown and ホーム still lists `1,200円`.

**AC-E-111** — Given the built app. On Android, its backup rules include the
database and the photos for cloud backup and device transfer. On iOS, neither
the database nor the photos is excluded from backup.

## 8. Delivery order

Build in this order. Each stage leaves `make check` green and its own criteria
passing, so progress is real even if the product is unfinished.

1. **Foundation** — the on-device database with sync-ready records, ledgers, isolation, the introduction. AC-B-104, AC-B-107, AC-B-108, AC-F-102, AC-E-101.
2. **Recording money** — categories, transactions, line items, search, income, recurring rules. AC-B-201 to AC-B-208, AC-F-201 to AC-F-204, AC-E-201.
3. **Reporting and calendar** — monthly report, daily totals, trend, charts, calendar with the NMD badge. AC-B-301 to AC-B-303, AC-F-301, AC-F-302.
4. **Budget and savings** — budgets, remaining, month close, carry or save. AC-B-401 to AC-B-403, AC-F-401.
5. **Photos and scanning** — photo storage, the document scanner, on-device text recognition, drafts. AC-B-501, AC-B-503 to AC-B-506, AC-F-501, AC-E-501.
6. **Receipts that do not add up** — AC-B-508, AC-F-502.
7. **Needs-review records** — AC-B-509, AC-F-503.
8. **Pace and notifications** — learned pace, alerts, the notification list, local OS notifications. AC-B-601 to AC-B-604, AC-F-601.
9. **Theme** — the look chosen on the device (style, theme colour, brightness, NMD badge). AC-F-701.
10. **Widget** — the home-screen widget on both platforms. AC-B-801, AC-F-801.
11. **Transit IC card** — NFC reading and history import. AC-B-901, AC-B-902, AC-F-901.
12. **Backup** — the OS device backup and the backup file. AC-B-110, AC-B-111, AC-F-110, AC-E-111.

## 9. Definition of done

`make check` is green, `make status` reports every criterion of every stage
passing, and `quality/stage.txt` names the last stage. OPEN: this repository
has no `make status` and no `quality/stage.txt` yet.

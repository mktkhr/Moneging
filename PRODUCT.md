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
receipt photo becomes a draft entry without typing, and the user hears that
they are spending too fast while the month can still be steered.

In v1 the user is one person on one device. A user may keep several ledgers.
A household of a few people sharing one ledger is planned for v2.

## 2. Scope

### In scope (v1)

- Native applications: iOS (SwiftUI) and Android (Jetpack Compose), their
  logic shared through Kotlin Multiplatform (`clients/kmp`).
- Local only, and free: every record lives in a database on the device; the
  app works fully offline; there is no sign-in, no server and no network call
  of the app's own (the on-device modules Android downloads through Google Play
  services are the one exception, §6).
- Several ledgers on one device.
- Expenses and income, entered by hand or from a receipt scan, optionally split
  into line items.
- Recurring monthly entries, recorded automatically when their day comes.
- Receipt photographs: kept with the ledger on the device, listed, deleted.
- Receipt scanning on the device, read in the background: a receipt is
  captured with the OS document scanner or picked from the photo library, its
  text recognised on the device, and the text structured into an editable
  draft by an on-device LLM where the device has one, or by a rule-based parser
  where it does not. Progress is shown as a Live Activity on iOS and an ongoing
  notification on Android.
- A first-launch guided tour over the app itself: creating the first ledger,
  the main controls, why the app asks to post notifications, and whether to
  enable reading from photos. It can be replayed.
- Monthly budgets per category, with the leftover carried over or saved.
- Learned spending pace per category, and a notification — in the app's list
  and as a local OS notification — when a category runs ahead of it.
- Reports: monthly totals by category, a day-by-day total, a twelve-month trend.
- A calendar view of daily spending, including days with no spending at all.
- A look chosen on the device: five styles, six theme colours, light or dark,
  the NMD badge, and on Android the device's dynamic colour as an option.
- A home-screen widget showing, for a ledger chosen in the widget's
  configuration, this month's budget against actual spending, the remaining
  budget, and the largest expense this month.
- Backup: the app's data is included in the OS device backup (iCloud backup,
  Android Auto Backup; §6 says what each holds), and the whole database, photos
  included, is exported to and imported from one file through the OS share
  sheet and file picker, so a user can move between devices and between iOS and
  Android.

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
- Bank, card or e-money account synchronisation.
- Transit IC cards and NFC: Mobile Suica in Apple Wallet and Osaifu-Keitai
  cannot be read by third-party apps, and physical cards are rarely used.
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
| **User** | The person using the app on a device. v1 has no accounts: nobody signs in and nothing identifies the user outside the device. The user carries their own look: a style, a theme colour, a brightness, an NMD badge and, on Android, whether the device's dynamic colour is used (see §5 Look). The look is kept on the device, identical in every ledger. A user who never chose has やさしい・あたたかい, テラコッタ, the device's brightness and にっこり硬貨. |
| **Ledger** | A book of money on the device. Every transaction, budget, photo and category belongs to exactly one ledger. A device may hold several ledgers, and the user always acts within one of them. A ledger has a name, which the user may change: surrounding whitespace is removed, and what remains is 1 to 20 characters, counted as the user sees them (an emoji is one character). Names need not be unique. |
| **Category** | A bucket for spending, scoped to a ledger. The default set is 食費, 日用品, 住居, 水道光熱費, 交通費, 通信費, 医療, 教育, 娯楽, 交際費, 衣服, その他. A ledger may add, rename and archive its own; an archived category keeps its history but takes no new transactions. |
| **Transaction** | One movement of money on one date: a direction (expense or income), an amount, a category (an expense only: income has none), an optional memo, an optional store name and an optional link to a photo. The amount is at least 1 yen. The date is a calendar date, not an instant. Each transaction records the identifier of the device it was recorded on, so that v2 sharing can attribute it. The store name is filled from a confirmed draft and may be set or changed by hand. A transaction confirmed from a draft whose items did not add up is marked needs-review (`needsReview`); the mark is cleared when a user marks it reviewed, or by any change that leaves it with no item named exactly `差額`, and it is never set by hand. A transaction recorded by a recurring rule names that rule, and is otherwise an ordinary transaction: it may be changed or deleted like any other. |
| **Line item** | A transaction may instead be split into several items, each with its own amount, category and optional item name. When a transaction has items, its amount equals the sum of its items, and each item is at least 1 yen. An item name is filled from a confirmed draft and may be set or changed by hand. |
| **Recurring rule** | An expense or an income that repeats every month, from a start month to an optional end month, on a day of the month (1 to 31) or on the month's last day; a day the month does not have means its last day. When that date is not a business day, the rule keeps it, moves it to the next business day or moves it to the previous business day, as chosen (kept unless chosen). A business day is a weekday that is neither a Japanese public holiday nor 31 December to 3 January. Public holidays are computed on the device from the Public Holiday Act — the named days, the vernal and autumnal equinoxes, substitute holidays and citizens' holidays — since nothing is fetched. A month's transaction of a rule is recorded automatically once its date has come (Asia/Tokyo), whenever the app runs; months that passed while it did not run are recorded on the next run. Materialising a rule's month creates its transaction exactly once, whatever the number of attempts, and it remains that month's transaction even when moving the date puts it in another month. Changing or ending a rule affects only the months not yet recorded; recorded transactions stay. Ending a rule sets its end month to the last month it recorded, so nothing more is recorded. An ended rule is resumed by clearing its end month; the months whose date came while it was ended are not recorded. Deleting a rule removes it; the transactions it recorded stay, still marked as recorded by a rule. A recorded transaction the user deletes is not recorded again: the month counts as done. |
| **Photo** | An image belonging to a ledger. Its bytes live in the app's private storage on the device; its record carries the content type, the size and the capture instant. Deleting a photo removes the stored bytes as well as the record. A photo referenced by a transaction cannot be deleted until the reference is removed. |
| **Scanner** | A reader of receipts, entirely on the device, in three steps. Capture: the OS document scanner (VisionKit on iOS, the ML Kit document scanner on Android), where a session of several pages yields one receipt per page, or one or several photos picked from the photo library. Text recognition: Vision on iOS, ML Kit text recognition on Android. Structuring the recognised text into a draft: an on-device LLM — Foundation Models on iOS devices with Apple Intelligence, Gemini Nano through ML Kit GenAI (AICore) on Android devices that support it — or, on a device without one, a deterministic rule-based parser. Every path answers the same question — store name, date, total, line items, each with the scanner's confidence — so the product never branches on which one is in use. A scan costs nothing per use, so there is no scan quota. Reading from photos works only while the user has it enabled (see **Photo reading**). |
| **Photo reading** | Whether the device reads receipts from photos, chosen by the user during onboarding and changeable at any time afterwards. When it is enabled, on Android the modules it needs — the ML Kit document scanner and text recognition, through Google Play services, and Gemini Nano only on a device that supports it — are downloaded then. iOS needs no download: its scanner, text recognition and Foundation Models are part of the OS, Foundation Models only on devices with Apple Intelligence. |
| **Scan job** | The reading of one photo, in the background: sending a photo never waits for its reading, and the user may send more, record by hand or leave the app meanwhile. Moves `queued → running → succeeded` or `→ failed`, never backwards. A failed job carries a human-readable reason. A job left running longer than its deadline, or cut off because the app ended, becomes failed. While a ledger's jobs are queued or running, their progress is shown outside the app: as a Live Activity on iOS and as an ongoing notification on Android. Jobs and waiting drafts are read from the database, so reopening the app finds them again. |
| **Draft** | The result of a succeeded scan: a proposed store name, date, total and line items (each with a name, an amount and optionally a category), each field carrying the scanner's confidence. A succeeded scan always keeps the items it read, even when they do not add up to the total it read. A draft is not a transaction until a user confirms it, and any field may be corrected first, its category and items included. Confirming a draft with items creates one expense with the draft's store and date, linked to the photo, and one line item per draft item; an item without a category is confirmed into その他. When the items add up to the total, the expense is the total. When they do not, confirming is refused unless the user accepts the mismatch (`acceptMismatch`), and then the expense is marked needs-review: below the total, the expense is the total and gains, after the items, one item `差額` of the difference, in the items' category when every item names the same active one, else その他; above the total, the expense is the items' sum. A user may instead record the total alone by removing the items: a draft with no items confirms into one unsplit expense of its total in its category, or その他 when it has none, with its store and date, linked to the photo. A draft may also be discarded. Either way it is gone afterwards. |
| **Budget** | For one ledger and optionally one category: a planned amount, set from a month on and continuing into every later month until another amount is set or the budget is removed from a month on. A month has at most one budget per category and at most one whole-month budget. Remaining is the budget, plus whatever was carried into it, minus the spending recorded against it; it may be negative. A category budget counts its category's expenses, split items included; the whole-month budget counts every expense. |
| **Carry-over policy** | What happens to a month's leftover when the month closes: `carry` moves each budget's leftover into the same budget next month, `save` moves it to savings — the whole-month budget's leftover when there is one, otherwise the category budgets' leftovers added up. A negative leftover moves nothing. Chosen per ledger (`carry` until changed), changeable, and applied once per month. A month closes only by the user's request, only after it has ended (in Asia/Tokyo), and only when every earlier month that has a budget is closed; a closed month's budgets are final. |
| **Savings** | A per-ledger running balance that only grows by closing a month under the `save` policy, with each contribution recorded against its month. |
| **Pace** | For a ledger, a category and a day: the spending expected by that day, learned from how the category was spent in the three calendar months before the day's month, a month with no spending counting as zero. For each of those months, what the category had spent up to and including the same day of the month is taken (the whole month when the month is shorter), and the expectation is their average, rounded down to a whole yen. A category paid at month end, such as rent, therefore expects nothing until its day. A category with no spending in any of the three months has no expectation (not 0). The learned monthly amount, shown for context, is the average of the three months' whole spending, rounded down. Spending is expenses only, split items counted in their own category; income never counts. A category is _ahead of pace_ when spending to date exceeds the expectation by more than 20%, computed in integers (spent × 10 > expected × 12), and only when the expectation is at least 1 yen: an expectation of 0 is never exceeded. |
| **Notification** | A message in a ledger: its kind, its text, the instant it was raised, and whether it has been read. Notifications are listed in the product, and each one is also posted, when it is raised, as a local OS notification on the device, if the user has allowed notifications; nothing is sent off the device. The one kind is a pace alert: when a category goes ahead of pace in a month, a notification naming it is raised, once when it first goes ahead and again only after an evaluation has found it back within pace, however often pace is evaluated. This is kept per ledger, category and month. An archived category never raises one. Pace is evaluated for the ledger's today in Asia/Tokyo after an expense is written and whenever the ledger's notifications are viewed, and for any date up to today on request; a later date is refused. The text is Japanese, composed by the product when the notification is raised: `食費のペースが速めです（2月15日までに19,000円・目安15,000円）`. Marking one read is idempotent, and all of them may be marked read at once. Opening the OS notification of a pace alert takes the user to the notifications of its ledger. |
| **Backup file** | One file holding a device's whole database — every ledger and every record in it, tombstones included — and the bytes of every photo, in a format that is the same on iOS and Android. Importing a file replaces all data on the device with the file's, after the user confirms it; nothing is merged. |

## 4. API contract

v1 has no API: the app makes no network request, and every operation is a call
into the shared Kotlin Multiplatform logic on the device.

The v2 server API will be contract-first: a spec under `contracts/openapi` is
the source of truth, the server interface and the clients are generated from
it, and the spec changes before the code does.

## 5. User interface

Screen composition — which screens exist, how the user moves between them,
their layout, and where each control sits — is not decided yet. It will be
added to this section when it is. Until then this section states only rules
that hold whatever the composition, and a criterion that depends on it is
marked `OPEN: depends on screen composition`.

**General.** Japanese, native — SwiftUI on iOS, Jetpack Compose on Android —
and usable one-handed on a phone. The app is named `Moneging` on the home
screen. The user always acts within one ledger, can change which, can add a
ledger and rename one, and the app reopens on the ledger last in view.
Month-based figures are shown for one month in view, the current month until
the user changes it; the app keeps the month in view when it returns from the
background. Every view of data has a loading state, an empty state and an
error state; a failed operation is always shown to the user, never swallowed.

**Formats.** Amounts are shown as `1,200円`, dates as `2月3日`, months as
`2026年2月`, instants as `2月15日 9:12`. A budget reads `残り 11,500円` with
`予算 30,000円`; an overspent one reads `1,500円オーバー`; a category spent
without a budget shows what was spent. A recurring rule reads
`毎月25日 80,000円 住居`, a month-end one `毎月末日`, an income one
`毎月25日 250,000円 収入`, and a moved one adds `土日祝なら翌平日` or
`土日祝なら前の平日`; its next date reads `次回 2月25日（水）`, and an ended
one has no next date and reads `2026年2月まで`. A transaction
recorded by a rule is marked `定期`. Shares are whole percentages that add up
to 100%.

**Recording.** A transaction is recorded with a date (today unless changed), a
direction (`支出` or `収入`), an amount, a category, an optional store name
and an optional memo, and may later be changed or deleted. An amount reads
with separators while it is typed (`1,200`). Recurring rules are listed with
the ended ones below the others, under `終了した定期`; choosing a rule opens it
to be changed, ended (`この定期を終了`) or deleted (`削除`), and deleting asks
first. The month's
transactions are listed newest first with the month's `支出` and `収入`
totals; a transaction with a store shows it. An archived category is marked
`アーカイブ済み` and is not offered when recording; archiving one asks for
confirmation first. When a month that has ended is still open, the product
offers to close it and says what the carry-over policy will do.

**Reports and calendar.** A day's total is named by its date and total
(`2月3日 4,000円`). A past day with no spending shows the **NMD** (No Money Day)
badge, an illustrated icon, and is named `2月4日 NMD`; today, future days and
days before the ledger was created never show it. Every chart shows its
figures as text beside it: the share as a list of category, amount and
percentage (`食費 3,000円 50%`), the trend as a list of month and amount
(`2025年4月 1,000円`). Income is never charted as spending. The calendar shows
the month in view in weeks starting on Sunday; each day shows its spending in
full (`4,000`), and income is not shown on it. Choosing a day lists its
transactions below the calendar. The month's share is drawn as a ring with its
list beside it, largest first; the trend as twelve bars ending with the month
in view, with its list below them.

**Look (見た目).** As in takamai: `スタイル` is one of やさしい・あたたかい,
すっきり・ミニマル, 落ち着いた・大人っぽい, 元気・カラフル and かわいい;
`テーマカラー` one of テラコッタ, ローズ, ラベンダー, ソーダ, セージ and 墨;
`明るさ` one of `端末に合わせる` (the device's light or dark, followed as it
changes), `ライト` and `ダーク`; `NMDバッジ` one of にっこり硬貨, ふたば and
きらり星, the badge the calendar shows. On Android the device's dynamic colour
may be chosen as an option. A choice applies at once, with no separate save
step, and is saved on the device, so it holds in every ledger. A save that
fails puts the previous look back and says so (`見た目を保存できませんでした`).
The app opens in the saved look from its first frame, and the widget follows
the look. OPEN: takamai defines the five styles and six colours as web styles
(fonts, shapes, CSS colours); how each maps onto SwiftUI and Compose theming.
OPEN: whether Android's dynamic colour is on or off for a user who never chose,
and how it combines with the chosen theme colour.

**Onboarding.** When the device holds no ledger, as on first launch, the app
opens with a guided tour over the app itself, not a separate set of screens:
each step dims the app, highlights one control and explains it in a callout.
The first step creates the first ledger: its name, filled in with `家計`, is
entered in the callout, the ledger in view shows the name as it is typed, and
this step cannot be skipped. The later steps explain recording, the ledger's
other views (calendar, report, budget), why the app posts notifications (pace
alerts), explained before the OS asks for permission to post them, and whether
to enable reading from photos (see Photo reading, §3); each of them offers to
skip the rest of the tour. The tour is finished when its last step is done or
the rest is skipped. If the app ends before then, the next launch resumes the
tour at the first step not yet done. The tour starts again from its first step
only if the device ever holds no ledger again, and it can be replayed from the
settings, without the ledger step.

**Receipt reading.** Photos are given either by scanning with the OS document
scanner (one receipt per page) or by picking one or several from the photo
library. Every photo given is kept as it is and its scan started, and the user
is told how many were accepted (`2枚の読み取りを受け付けました`). While scans
are in flight or drafts wait, the product shows how many
(`読み取り中 1件・確認待ち 2件`), and progress is also shown outside the app
(§3 Scan job). A waiting draft shows its store and total
(`セブン-イレブン 1,180円`); a scan in flight says so; a failed scan shows its
reason and lets the user record the expense by hand, linked to the photo, or
read the photo again. A draft shows its photo and every field editable: `店名`,
`日付`, `合計`, and the items as `品名`, `金額` and `カテゴリ`, each item
removable, and items may be added. A draft with no items has one `カテゴリ`
for the whole expense, left empty for その他. A field whose confidence is below
0.6 is marked `要確認`. The photo stays with the confirmed record and can be
viewed from it (`レシートの写真を見る`).

While a draft has items whose sum differs from `合計`, the user is warned with
the items' sum, the total and the difference
(`明細の合計 830円 が合計 980円 と 150円 合いません。`), the items' sum is shown
in the warning colour, and two fixes are offered: adding an item `差額` of the
difference, only when the sum is below the total, in the items' category when
every item names the same one, else その他; and recording the total alone,
which removes every item and offers the whole-expense `カテゴリ`. Confirming
saves the corrections and confirms the draft. While the items do not add up it
first asks `合計額が合いませんがよろしいですか？`, naming the three amounts
(`明細の合計 830円 と合計 980円 が 150円 違います。このまま記録すると、`) and
then saying, when the sum is below the total,
`差額 150円 を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。`,
or, when it is above, `明細の合計 1,030円 で記録し、要確認の印を付けます。`.
Declining returns to the draft unconfirmed; accepting saves the corrections and
confirms the draft accepting the mismatch. Discarding a draft asks first.
OPEN: takamai's warning went on to point at buttons below it; its full wording
is settled with the screen composition.

**Needs-review.** A record confirmed with its mismatch accepted is marked
`要確認` until a user resolves it. While any record of the ledger is marked,
the product shows `要確認 N件` with `明細が合計と合わないまま記録したもの`, and
never with N of 0, and it can list every marked record of the ledger, whatever
its month, newest first (`月をまたいで、印が付いている記録をすべて表示します`).
Wherever a marked record is listed it carries a `要確認` mark. The marked
record itself explains
`要確認：読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。`
(the amount of its `差額` item; without one,
`要確認：読み取った明細が合計と合わなかったため写真を見て直してください。`),
and its `差額` item is marked with the warning colour. The user can mark it
reviewed as it is (`このままで確認済みにする`), told that
`「差額」をなくして保存するか「確認済みにする」を押すと、要確認の印が消えます`;
saving the record without its `差額` item clears the mark too.

**Notifications (お知らせ).** While any notification of the ledger in view is
unread, the product shows the unread count, which its accessible name carries
too (`お知らせ（未読2件）`); with none unread it is named `お知らせ` alone. The
count is read from the database, again whenever the ledger changes and when the
app returns to the foreground. The ledger's notifications are listed newest
first, each showing its text and when it was raised (`2月15日 9:12`). An unread
one is marked with a dot and bold text and says `未読` to a screen reader; a
read one is dimmed. Opening a notification marks it read and leaves the list in
view; all of them can be marked read at once (`すべて既読`). With no
notifications the list reads `お知らせはありません`. A pace alert is also
posted as a local OS notification carrying the same text; opening it opens the
app on the notifications of its ledger. When the user has not allowed
notifications, alerts still appear in the list and nothing else changes.

**Widget.** A home-screen widget (WidgetKit on iOS, Glance or an App Widget on
Android) shows one ledger, chosen in the widget's configuration: this month's
whole-month budget, the actual spending against it and the remaining budget,
and the largest expense this month. When the month has no whole-month budget,
it shows the actual spending and the largest expense. It shows what the
database holds, updated whenever a transaction or a budget changes, in the
user's look. OPEN: whether the widget also offers a quick way to start an entry
(takamai's `記録する`); it depends on screen composition.

**Backup (バックアップ).** The user can write the backup file and hand it to
the OS share sheet (`データを書き出す`), and import one chosen in the OS file
picker (`データを読み込む`). Before importing, the user is asked to confirm
that all data on the device will be replaced; declining changes nothing. The
same file imports on iOS and on Android. A file that is not a backup file is
refused with `このファイルは読み込めません`, and nothing changes. Besides this,
the app's data is included in the OS device backup (§6).

## 6. Non-functional requirements

- **Money.** Integer yen throughout, in storage, in the shared logic and in the
  UI.
- **Local only.** v1 makes no network request of its own; every feature works
  with the device offline, from first launch. The one download is on Android:
  when the user enables reading from photos, the ML Kit document scanner and
  text recognition modules, and Gemini Nano on a supported device, are
  downloaded then through Google Play services. iOS downloads nothing.
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
- **Device backup.** On iOS the database and the photos are included in the
  iCloud backup. On Android, Auto Backup holds the database only (it keeps at
  most 25 MB per app); photos are covered by the backup file.
- **Isolation.** No operation in one ledger may read or write another ledger's
  data. This is proven by tests, not by review.
- **Asynchrony.** Scanning never blocks the interface. A scan that crashes
  leaves its job `failed`, never `running` forever.
- **Determinism in tests.** Time, the document scanner, text recognition, the
  on-device LLM, the module download, the notification permission prompt, the
  progress surface (Live Activity, ongoing notification) and the OS
  notification poster are injected, so tests never wait for a clock, a camera,
  a model, a network or the OS. A scanner that reads a fixture
  deterministically is part of the product.
- **Supply chain.** Every dependency and tool is pinned: Gradle dependencies
  through the version catalog, with the Gradle wrapper's checksum verified;
  Swift packages through a committed `Package.resolved`; every GitHub Actions
  step by commit SHA, so a movable tag anywhere fails the build; the toolchain
  in `mise.toml`.
- **Accessibility.** Every control is labelled and reachable with VoiceOver and
  TalkBack.
- **Safe areas.** Every control stays in full view, uncovered, and clear of the
  status bar, the home indicator or gesture bar, the screen's rounded corners
  and, held sideways, the sensor housing or display cutout; so do the corners
  of every dialog, sheet and menu.

## 7. Acceptance criteria

Every criterion has one test that carries its identifier, written before the
implementation. The harness runs each one; a criterion whose test does not
exist fails once its stage is open (`quality/stage.txt`). The tests live in
`acceptance/` (`acceptance/README.md`). `AC-B` identifiers name a test of the
shared logic in `acceptance/shared`, compiled against `clients/kmp/sharedLogic`
and run on the Android host and the iOS simulator. Every `AC-F` and `AC-E`
criterion is tested on both platforms: its identifier appears in the title of
a platform UI test, an XCUITest in `acceptance/ios` (written `AC_F_102`, since
a Swift name cannot hold `-`) and a Compose UI test on Android. `AC-E` tests
drive the built app end to end on a simulator or emulator. The one exception
is the widget on iOS: its criteria are verified by unit tests of the widget's
data and timeline provider, carrying the identifier in their title, not by
XCUITest.

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
| AC-B-109 | A ledger's name is trimmed and 1 to 20 characters, when created and when renamed.      | `TestLedgerNames`           |
| AC-F-102 | A first-time user creates a ledger through the onboarding.                             | `AC-F-102`                  |
| AC-F-103 | A ledger is added, changed to, and renamed.                                            | `AC-F-103`                  |
| AC-F-104 | The tour resumes where it stopped, ends when skipped, and can be replayed.             | `AC-F-104`                  |
| AC-E-101 | On first launch, offline, the app opens the onboarding with no sign-in.                | `AC-E-101`                  |

**AC-B-104** — Given a device with no ledger. When the ledger `家計` is
created, then the ledgers listed are exactly `家計`, with the twelve default
categories.

**AC-B-107** — Given ledgers `A` and `B`, `B` named `花子の家計`, with a
category and a photo in `B`. When, acting within `A`, that category and that
photo are read by their identifiers, then neither is found, and nothing
returned names `花子の家計`. When `B` is read, then it is `花子の家計`,
unchanged.

**AC-B-108** — Given the clock at 2026-02-15 12:00 and the device identifier
`D`. When a ledger, a category, a transaction with two line items, a budget and
a recurring rule are created, then each has a UUID identifier and created and
updated instants of 12:00, and the transaction records the device `D`.
When the clock moves to 12:05 and the transaction's memo is changed, then its
updated instant is 12:05 and its created instant still 12:00. When it is
deleted, then it is neither found nor listed nor counted in any total, and the
database still holds it, with its items, as a tombstone deleted at 12:05.

**AC-B-109** — Given the ledger `家計`, created at 12:00. When a ledger is
created with the name `  我が家  `, then it is named `我が家`. When a ledger is
created with an empty name, or one of spaces only, or of 21 characters, then
it is refused and the ledgers listed are still `家計` and `我が家`. A name of
20 characters, one of them the emoji `🏠`, is accepted as it is. When the
clock moves to 12:05 and `家計` is renamed ` 家計2026 `, then it is named
`家計2026`, its updated instant is 12:05 and its created instant still 12:00;
renaming it to a name of spaces only is refused and leaves `家計2026`.

**AC-F-102** — Given a device with no ledger. When the app is opened, then the
tour's first step is shown, its name holding `家計` and the ledger in view
reading `家計`. When the name is changed to `我が家`, then the ledger in view
reads `我が家` before anything is created. When the ledger is created and the
rest of the tour is done, then the ledger `我が家` exists and is the ledger in
view. When the app is relaunched, then `我が家` is in view and the tour is not
shown.

**AC-F-103** — Given the ledger `家計` in view. When a ledger named `旅行` is
added, then `旅行` is in view, and both `家計` and `旅行` are offered to change
to. When `家計` is chosen, then `家計` is in view. When `旅行` is renamed
`沖縄旅行`, then `沖縄旅行` is offered in its place. While a name is empty or
longer than 20 characters, a ledger cannot be added or renamed with it.

**AC-F-104** — Given a device with no ledger. When `家計` is created through
the tour and the app is relaunched before the next step is done, then the tour
resumes at that next step, with `家計` in view. When the rest of the tour is
skipped, then the tour ends, and a relaunch does not show it. When the tour is
replayed from the settings, then it starts at the step after the ledger step,
and `家計` is still the only ledger.

**AC-E-101** — Given the built app, freshly installed, on a device with no
network. When it is launched, then the onboarding is shown with no sign-in, and
creating `家計` through it leaves `家計` in view.

### Recording money

| ID       | Criterion                                                             | Test                                         |
| -------- | --------------------------------------------------------------------- | -------------------------------------------- |
| AC-B-201 | A transaction is created, read, updated and deleted.                  | `TestTransactionLifecycle`                   |
| AC-B-202 | An amount is an integer number of yen and at least one yen.           | `TestAmountIsIntegerYen`                     |
| AC-B-203 | A transaction split into line items has items summing to its amount.  | `TestLineItemsSumToTotal`                    |
| AC-B-204 | Transactions are searched by period, category and text.               | `TestTransactionSearch`                      |
| AC-B-205 | Income is recorded and the month's balance is income minus expense.   | `TestMonthlyBalance`                         |
| AC-B-206 | Recurring rules are recorded automatically on their date, once.       | `TestRecurringMaterialisation`               |
| AC-B-207 | An archived category keeps its history and takes no new transactions. | `TestArchivedCategoryRejectsNewTransactions` |
| AC-B-208 | An operation in one ledger cannot read or write another's transactions. | `TestLedgerIsolationForTransactions`       |
| AC-B-209 | Business days follow Japanese public holidays and the year-end break. | `TestBusinessDays`                           |
| AC-B-210 | Income carries no category.                                           | `TestIncomeHasNoCategory`                    |
| AC-B-211 | A recurring rule is ended, resumed and deleted; recorded ones stay.   | `TestRecurringRuleLifecycle`                 |
| AC-F-201 | The month's transactions and total are listed.                        | `AC-F-201`                                   |
| AC-F-202 | A transaction is created and edited from the interface.               | `AC-F-202`                                   |
| AC-F-203 | Categories are added, renamed and archived from the interface.        | `AC-F-203`                                   |
| AC-F-204 | A recurring rule is set up and records itself when its date comes.    | `AC-F-204`                                   |
| AC-F-205 | A recurring rule is changed, ended, resumed and deleted from the interface. | `AC-F-205`                             |
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

**AC-B-204** — Given three expenses in 2026-02: 1,000 食費 memo `スーパー`,
2,000 食費 memo `外食` and 3,000 交通費 memo `電車`; and 4,000 食費 in 2026-01.
When searched by period 2026-02-01..2026-02-28, then three are returned. When
also by category 食費, then two. When also by text `外`, then one, of 2,000.
When searched by amount 2,000..3,000 in that period, then two.

**AC-B-205** — Given 2026-02 with expenses 1,000 and 2,000 and an income of
5,000. When the month's summary is read, then income is 5,000, expense is 3,000
and the balance is 2,000.

**AC-B-206** — Given a rule of 80,000 yen 住居 on day 25, moved to the next
business day, from 2026-01 with no end; a rule of 250,000 yen income on the
month's last day, moved to the previous business day, from 2026-01; and a
manual expense of 1,000 食費 on 2026-02-25. When materialisation runs three
times with today 2026-04-24, then the 住居 rule has exactly one transaction for
each of 2026-01, 2026-02 and 2026-03, dated 2026-01-26 (the 25th is a Sunday),
2026-02-25 and 2026-03-25, and none yet for 2026-04; the income rule has one
for each of 2026-01, 2026-02 and 2026-03, dated 2026-01-30 (the 31st is a
Saturday), 2026-02-27 (the 28th is a Saturday) and 2026-03-31, with no
category; each names its rule; and the manual expense is untouched. When today
becomes 2026-04-27 and materialisation runs, then the 住居 rule gains exactly
one transaction, dated 2026-04-27 (the 25th is a Saturday). When the 住居 rule
is changed to 85,000 yen, then the recorded ones stay 80,000 and 2026-05's is
recorded as 85,000 once its date comes. When the 2026-02 住居 transaction is
deleted and materialisation runs again, then it is not recorded again.

**AC-B-209** — When the next business day is read for 2026-05-03, then it is
2026-05-07 (Constitution Day, Greenery Day, Children's Day and the substitute
holiday on the 6th). For 2026-09-19, it is 2026-09-24 (Respect for the Aged
Day on the 21st, the autumnal equinox on the 23rd and the citizens' holiday
between them). For 2026-12-31, it is 2027-01-04. When the previous business
day is read for 2027-01-03, then it is 2026-12-30, and for 2026-03-20 (the
vernal equinox), 2026-03-19. 2026-02-25 is its own business day either way.

**AC-B-210** — Given the ledger `家計`. When an income of 5,000 yen is recorded,
then it reads back with no category. When an income is recorded with the
category 食費, then it is refused as invalid. When an expense is recorded with
no category and no items, then it is refused as invalid.

**AC-B-211** — Given today 2026-02-26 and a 住居 rule of 80,000 yen on day 25,
kept on non-business days, from 2026-01, whose 2026-01 and 2026-02
transactions have been recorded. When it is ended, then its end month reads
2026-02, and when today becomes 2026-03-26 and materialisation runs, then
nothing is recorded for 2026-03. When, on 2026-04-10, its end month is cleared,
and today becomes 2026-04-26 and materialisation runs, then exactly one
transaction is recorded for 2026-04, dated 2026-04-25, and 2026-03 still has
none. When the rule is deleted, then it is no longer listed, and the
transactions of 2026-01, 2026-02 and 2026-04 remain, each still naming it.

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
month's transactions are viewed, then they are the three February transactions
newest first — `3,000円` 交通費, `1,200円` 食費 `ランチ`, `5,000円` — with `支出`
`4,200円` and `収入` `5,000円`, and the January one is not among them.

**AC-F-202** — Given today 2026-02-15 and a February with no transactions. When
the user records an expense with amount `1200`, category 食費 and memo `ランチ`,
leaving the date unchanged, then while it is typed the amount reads `1,200`,
and an expense of 1,200 食費 on 2026-02-15 with
memo `ランチ` is created, and the month's transactions list `1,200円` with
`支出` `1,200円`. When the user changes that transaction's amount to `1500`,
then it is updated and the list and `支出` show `1,500円`.

**AC-F-203** — Given today 2026-02-15 and a ledger with the default
categories. When the ledger's categories are viewed, then the twelve defaults
are listed in order. When the user adds `ペット`, then it is created and listed
last. When the user renames 娯楽 to `趣味`, then it is listed as `趣味`. When the
user archives 趣味 and confirms, then it is listed as `アーカイブ済み` and is
not offered when recording.

**AC-F-204** — Given today 2026-02-26 and a ledger with no recurring rules.
When the user adds a rule with amount `80000`, category 住居, day `25`,
`土日祝なら翌平日` and start month 2026-02, then it is listed as
`毎月25日 80,000円 住居` with `土日祝なら翌平日` and `次回 3月25日（水）`, and,
with nothing more done, the month's transactions list `80,000円` 住居 marked
`定期` on 2026-02-25. When the user adds an income rule of `250000` on the
month's last day, then it is listed as `毎月末日 250,000円 収入` and no
category is asked for.

**AC-F-205** — Given today 2026-02-26 and a ledger with the rule
`毎月25日 80,000円 住居`, `土日祝なら翌平日`, from 2026-02, that has recorded
its 2026-02-25 transaction. When the user opens the rule and changes its amount
to `85000`, then it is listed as `毎月25日 85,000円 住居`, and the month's
transactions still list `80,000円` 住居 marked `定期`. When the user opens it
and chooses `この定期を終了`, then it is listed under `終了した定期` with
`2026年2月まで` and no `次回`. When the user opens it and sets `終了` back to
`なし`, then it is listed above `終了した定期` again with `次回 3月25日（水）`.
When the user opens it, chooses `削除` and confirms, then no rule is listed,
and the month's transactions still list `80,000円` 住居 marked `定期`.

**AC-E-201** — Given the built app, freshly installed. When the user creates
`家計` through the onboarding and records an expense of 1,200 食費, then the
month's transactions list `1,200円` 食費 with `支出` `1,200円`, and after the
app is terminated and relaunched both are still shown.

### Reporting and calendar

| ID       | Criterion                                                           | Test                      |
| -------- | ------------------------------------------------------------------- | ------------------------- |
| AC-B-301 | A month reports totals by category.                                 | `TestMonthlyReport`       |
| AC-B-302 | A month reports a total for every day, including zero days.         | `TestDailyTotalsForMonth` |
| AC-B-303 | The last twelve months report a total each.                         | `TestTwelveMonthTrend`    |
| AC-F-301 | Monthly totals by category are charted.                             | `AC-F-301`                |
| AC-F-302 | The calendar shows daily totals and an NMD badge on past zero days. | `AC-F-302`                |

**AC-B-301** — Given 2026-02 with 1,000 and 2,000 食費, 3,000 交通費, an expense
of 3,000 split into 1,200 食費 and 1,800 日用品, an income of 5,000,
and 500 食費 on 2026-01-31 and 700 食費 on 2026-03-01. When the monthly report
is read, then it lists 食費 4,200, 交通費 3,000 and 日用品 1,800 in that order
(largest first), the expense total is 9,000, and income is not counted in any
category.

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
income of 5,000, 1,000 食費 in 2025-04, and today 2026-02-15. When the month's
report is viewed, then the month's share lists 食費 `3,000円` `50%` and 交通費
`3,000円` `50%` and nothing else, and the trend lists the twelve months from
`2025年3月` to `2026年2月`, with `2026年2月` `6,000円`, `2025年4月` `1,000円`
and the others `0円`.

**AC-F-302** — Given a ledger created on 2026-02-02, 2026-02 with 4,000 on the
3rd (1,500 食費 スーパー and 2,500 日用品), 800 on the 10th, and nothing on the
1st, the 4th, the 15th and the 20th, with today 2026-02-15. When the month's
calendar is viewed, then the 3rd shows 4,000 (`2月3日 4,000円`), the 4th shows
the NMD badge (`2月4日 NMD`), and the 1st (before the ledger), the 15th and the
20th do not. When the 3rd is chosen, then its two transactions are listed and
the 10th's is not.

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
When the month's budgets are viewed, then the whole month shows `28,500円`
remaining with `予算 50,000円`, 食費 shows `残り 11,500円` `予算 30,000円`, and
交通費 shows `3,000円` without a budget. When the user adds a 交通費 budget of
5,000 from 2026-02, then 交通費 shows `残り 2,000円` `予算 5,000円`.

### Photos and scanning

| ID       | Criterion                                                             | Test                            |
| -------- | --------------------------------------------------------------------- | ------------------------------- |
| AC-B-501 | A photo is kept, listed and deleted, and its bytes go with it.        | `TestPhotoLifecycle`            |
| AC-B-503 | Starting a scan returns immediately with a job that completes later.  | `TestScanIsAsynchronous`        |
| AC-B-504 | A succeeded scan yields a draft with store, date, total and items.    | `TestScanProducesDraft`         |
| AC-B-505 | A draft is corrected field by field and confirmed into a transaction. | `TestDraftCorrectionAndConfirm` |
| AC-B-506 | A failed scan leaves a reason, and the photo stays usable by hand.    | `TestScanFailureIsRecoverable`  |
| AC-B-510 | The rule-based parser reads recorded receipt text into drafts, deterministically. | `TestRuleBasedReceiptParser` |
| AC-B-511 | Recognised text is structured by the on-device LLM when there is one, else by the rule-based parser. | `TestReceiptStructuringPath` |
| AC-F-501 | A scanned receipt shows its scan progressing, then an editable draft. | `AC-F-501`                      |
| AC-F-504 | Enabling reading from photos downloads what the device needs, then.   | `AC-F-504`                      |
| AC-E-501 | A user scans a receipt, corrects the draft and confirms it.           | `AC-E-501`                      |

The fixture scanner reads `acceptance/fixtures/receipts/`, shared by the
shared-logic and UI tests: `seven-eleven.jpg` beside `seven-eleven.json`, its
draft — store `セブン-イレブン`, date 2026-02-14, total 1,180, items おにぎり
380 in 食費 and 弁当 800 without a category (380 + 800 = 1,180), with the
confidences store 0.95, date 0.9, total 0.4, おにぎり 0.9 and 弁当 0.5. Beside
it is `corner-deli.jpg`, whose items do not add up (Receipts that do not add
up). It has no draft for any other image, whose scan fails. In UI tests the
fixture stands in for the OS document scanner, text recognition and
structuring, handing the app the fixture image as if it had been scanned.
Unless a criterion says otherwise, the scanner answers at once.

How recognised text becomes a draft is checked separately, from recorded text:
`acceptance/fixtures/receipt-text/` holds, for each receipt, the text that
on-device recognition produced from its photo (`seven-eleven.txt`,
`corner-deli.txt`) beside the draft the rule-based parser must produce from it
(`seven-eleven.rule.json`, `corner-deli.rule.json`). The on-device LLM is never
run in tests: a fake stands in for it, answering a recorded structured result
(`seven-eleven.llm.json`) or reporting that the device has no on-device LLM.

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

**AC-B-510** — Given the recorded texts `seven-eleven.txt` and
`corner-deli.txt`. When each is parsed by the rule-based parser, then the draft
equals the one recorded beside it, every field, item and confidence included;
for `seven-eleven.txt` that draft has store `セブン-イレブン`, date 2026-02-14,
total 1,180 and the items おにぎり 380 and 弁当 800. When each is parsed again,
then the draft is identical to the first.

**AC-B-511** — Given the recorded text `seven-eleven.txt` and a fake on-device
LLM answering `seven-eleven.llm.json`. When the text is structured, then the
draft is the fake's answer and the rule-based parser is not used. Given the
fake reporting that the device has no on-device LLM, when the same text is
structured, then the draft is the rule-based parser's, equal to
`seven-eleven.rule.json`, and the job's result has the same shape either way.

**AC-F-501** — Given today 2026-02-15, reading from photos enabled, a fake
progress surface, and the fixture scanner answering the draft of AC-B-504
(store `セブン-イレブン` confidence 0.95, date 2026-02-14 confidence 0.9, total
1,180 confidence 0.4; おにぎり 380 食費 confidence 0.9, 弁当 800 without a
category confidence 0.5), each scan job moving one state on at a time. When the
user scans one receipt with the document scanner, then the photo is kept as it
is and its scan started, the user is told `1枚の読み取りを受け付けました`, and
another scan can be started at once. While the job is queued or running, the
progress surface shows it (a Live Activity on iOS, an ongoing notification on
Android), and it ends when the job completes. The product shows `読み取り中`
and then `確認待ち 1件`, and the waiting draft as `セブン-イレブン` `1,180円`;
opening it shows every field editable with `店名` `セブン-イレブン`, `合計`
marked `要確認` (and `店名` not), and the items おにぎり and 弁当. When 弁当's
`金額` becomes 820 and `合計` 1,200 and the draft is confirmed, then it is saved
with those values (弁当 still without a category) and confirmed, `確認待ち`
disappears, and the month's transactions list `1,200円` with `セブン-イレブン`
with `支出` `1,200円`. Given a document-scanner session of two pages, when it
ends, then two photos are kept and two scans started
(`2枚の読み取りを受け付けました`); given two photos picked from the photo
library, the same.

**AC-F-504** — Given a fresh install and a fake module installer. When, during
the onboarding, the user enables reading from photos, then on Android the
installer is asked, then, for the ML Kit document scanner and text recognition
modules, and for Gemini Nano only when the device reports that it supports
it; on iOS nothing is downloaded. Given the user declined during the
onboarding, then nothing is downloaded and reading from photos is off; when
the user later turns it on, then the same download is requested at that time,
and the choice survives a relaunch.

**AC-E-501** — Given the built app, freshly installed, and the fixture scanner
handing it `seven-eleven.jpg`. When the user creates `家計`, enables reading
from photos, scans a receipt with the document scanner, waits for
`確認待ち 1件`, opens the draft, corrects `店名` to `セブンイレブン 新宿店`,
弁当's `金額` to 820 and `合計` to 1,200 and confirms it, then with 2026年2月 in
view the month's transactions list `1,200円` with `セブンイレブン 新宿店` and
`支出` `1,200円`.

### Pace and notifications

| ID       | Criterion                                                                             | Test                                 |
| -------- | ------------------------------------------------------------------------------------- | ------------------------------------ |
| AC-B-601 | Pace is learned from previous months, per category.                                   | `TestPaceLearnedFromHistory`         |
| AC-B-602 | A category ahead of pace raises one notification when it first goes ahead in a month. | `TestPaceAlertRaisedOncePerDay`      |
| AC-B-603 | Notifications are listed and marked read.                                             | `TestNotificationsListAndRead`       |
| AC-B-604 | A raised notification is posted once as a local OS notification.                      | `TestPaceAlertPostsLocalNotification` |
| AC-F-601 | Notifications are shown and can be marked read.                                       | `AC-F-601`                           |
| AC-F-602 | The onboarding explains notifications before the OS asks, and an OS notification opens its ledger's notifications. | `AC-F-602` |

**AC-B-601** — Given, in each of 2025-11, 2025-12 and 2026-01, 食費 spending
of 15,000 on the 10th and 15,000 on the 20th (January's 10th is an expense of
20,000 split into 15,000 食費 and 5,000 日用品) and a 住居 payment of 80,000 on
the 25th; an income of 50,000 on 2025-12-05; and 3,000 交通費 on
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
2026-02-14 at 20:31 and read (6,200 > 4,800 × 1.2 = 5,760). When the ledger is
in view, then 1 unread is shown (`お知らせ（未読1件）`). When the ledger's
notifications are viewed, then both are listed newest first, the unread one
marked `未読` and the read one not. When the unread one is opened, then it is
marked read, the list stays in view, and the unread count disappears: the
notifications are named `お知らせ` alone.

**AC-F-602** — Given a fresh install and a fake notification permission
prompt. When the onboarding reaches notifications, then it explains why the
app posts them, and the OS prompt has not been requested; when the user goes
on, then the OS prompt is requested exactly once. Given ledgers `家計` and
`実家` with `実家` in view, and the first notification of AC-F-601 raised in
`家計` and posted as an OS notification, when the OS notification is opened,
then the app shows `家計`'s notifications, the unread one among them.

### Theme

| ID       | Criterion                                                                             | Test       |
| -------- | ------------------------------------------------------------------------------------- | ---------- |
| AC-F-701 | The look is chosen, saved on the device, and survives a relaunch.                     | `AC-F-701` |

**AC-F-701** — Given the default look (やさしい・あたたかい, テラコッタ,
端末に合わせる, にっこり硬貨). When the user chooses the style `かわいい` and
the colour `ローズ`, then the interface's primary colour becomes ローズ's, the
choice is saved on the device (`cute` and `rose`, the brightness and the badge
unchanged), and the chosen options are shown as chosen. When the app is
relaunched, then the look is still かわいい / ローズ. When `ダーク` is chosen,
then the dark scheme is in use. On Android, when the device's dynamic colour is
chosen, then the device's dynamic colour scheme is in use; iOS does not offer
it.

### Receipts that do not add up

| ID       | Criterion                                                                                      | Test                         |
| -------- | ---------------------------------------------------------------------------------------------- | ---------------------------- |
| AC-B-508 | A scan whose items do not add up keeps them, and is confirmed only with the mismatch accepted. | `TestMismatchedDraftConfirm` |
| AC-F-502 | A draft warns of items that do not add up, offers to fix them, and asks before recording.      | `AC-F-502`                   |

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
items 唐揚げ弁当 680 and 緑茶 150, both 食費). When a receipt is scanned and
its draft, waiting as `コーナーデリ` `980円`, is opened, then it shows the two
items and the warning `明細の合計 830円 が合計 980円 と 150円 合いません。`,
and offers both to add the difference as an item and to record the total
alone. When the difference is added, then a third item `差額` 150 in 食費
follows the two and the warning goes; when the draft is confirmed, then it is
saved with the three items and confirmed without a question and without
`acceptMismatch`, `確認待ち` disappears and the month's transactions list
`980円` with `コーナーデリ`. Given a new draft of it, when `合計` becomes 800,
then the warning reads `明細の合計 830円 が合計 800円 と 30円 合いません。`
and adding the difference is not offered, and confirming asks
`合計額が合いませんがよろしいですか？` saying
`明細の合計 830円 で記録し、要確認の印を付けます。`; declining leaves the
draft open and nothing confirmed. When `合計` is 980 again and the draft is
confirmed, then the question says
`差額 150円 を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。`;
accepting saves the total 980 with the two items and confirms with
`acceptMismatch` true, which records 980 split into the two items and `差額`
150, marked needs-review, and the month's transactions list `980円` with
`コーナーデリ`. Given a new draft of it, when the user records the total alone,
then the items go and the whole-expense `カテゴリ` is offered, and confirming
confirms without a question: the draft is saved with no items and records 980
unsplit, not marked.

### Needs-review records

| ID       | Criterion                                                                                                   | Test                       |
| -------- | ----------------------------------------------------------------------------------------------------------- | -------------------------- |
| AC-B-509 | Needs-review records are listed across months, cleared by review or by removing 差額, never marked by hand. | `TestNeedsReviewLifecycle` |
| AC-F-503 | Needs-review records are counted, marked wherever listed, listed across months and marked reviewed.         | `AC-F-503`                 |

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
`差額` 640 in 日用品. When the ledger is in view, then it shows `要確認 2件`
`明細が合計と合わないまま記録したもの`, and the month's transactions show
`980円` `コーナーデリ` with the `要確認` mark and `1,150円` `カフェ` without.
When the calendar's `2月13日 980円` is chosen, then its `980円` `コーナーデリ`
carries the mark too. When the needs-review records are listed, then they are
`980円` `コーナーデリ` and `2,640円` `ドラッグストア みどり`, in that order,
each with the mark. When `コーナーデリ` is opened, then it explains
`要確認：読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。`,
and when the user marks it reviewed as it is, then `needsReview` false is saved
for it and the explanation goes; the count reads `要確認 1件` and
`コーナーデリ` in the month's transactions has no mark. When the needs-review
records are listed again, they are only `ドラッグストア みどり`, whose
explanation names `差額 640円`; when it too is marked reviewed, then no
`要確認` count or mark is shown at all.

### Widget

| ID       | Criterion                                                                        | Test                             |
| -------- | -------------------------------------------------------------------------------- | -------------------------------- |
| AC-B-801 | The widget's figures are its ledger's budget, spending, remaining and largest expense this month. | `TestWidgetShowsRemainingBudget` |
| AC-F-801 | The widget shows its configured ledger's figures in the user's look.             | `AC-F-801`                       |

**AC-B-801** — Given the budgets and expenses of AC-F-401 in `家計`, and a
ledger `実家` with one expense of 2,000 食費 in 2026-02 and no budget. When the
widget's content is read for `家計`, then it is the budget 50,000, spent
21,500, remaining 28,500, and the largest expense 18,500 食費. When an expense
of 1,000 食費 is recorded on 2026-02-15, then the widget's content is read
again as spent 22,500 and remaining 27,500, and a widget refresh has been
requested. When the widget's content is read for `実家`, then it has no budget
and no remaining, spent 2,000 and the largest expense 2,000 食費.

**AC-F-801** — Given the state of AC-B-801, a widget configured for `家計`, and
the look かわいい / ローズ. When the widget is shown, then it reads the budget
`50,000円`, spent `21,500円`, remaining `28,500円` and the largest expense
`18,500円` 食費, in ローズ's primary colour. When its configuration is changed
to `実家`, then it reads spent `2,000円` and the largest expense `2,000円` 食費,
and no budget or remaining. On iOS this is verified through the widget's data
and timeline provider (§7).

### Backup

| ID       | Criterion                                                                           | Test                        |
| -------- | ----------------------------------------------------------------------------------- | --------------------------- |
| AC-B-110 | Exporting and importing the backup file brings back every ledger, record and photo, replacing what was there. | `TestBackupRoundTrip`       |
| AC-B-111 | A file that is not a backup file is refused and changes nothing.                    | `TestBackupRejectsBadFiles` |
| AC-F-110 | The backup file is written through the share sheet and read through the file picker, after confirmation. | `AC-F-110`                |
| AC-E-111 | The app's data is included in the OS device backup.                                 | `AC-E-111`                  |

**AC-B-110** — Given ledgers `家計` and `実家` holding categories, transactions
with line items, a recurring rule, budgets, a closed month with savings, a
waiting draft, a notification, a photo linked to a transaction and a tombstone.
When the backup file is written and imported into an empty database, then every
record reads back identical, identifiers, instants and device identifiers
included, and the photo's bytes are byte-identical. Given a database holding a
ledger `別の家計`, when the same file is imported, then the database holds
exactly the file's records and `別の家計` is gone. The fixture files
`acceptance/fixtures/backup/android.backup` and
`acceptance/fixtures/backup/ios.backup`, one written on each platform from the
same records, both import into those records.

**AC-B-111** — Given `家計` with one transaction. When a text file, an empty
file and a truncated backup file are each imported, then each is refused as
invalid and `家計` still holds exactly its one transaction.

**AC-F-110** — Given `家計` with one expense of 1,200 食費. When the user
exports the data, then the OS share sheet opens with one backup file. When the
user imports and chooses a text file in the OS file picker, then
`このファイルは読み込めません` is shown and the month's transactions still list
`1,200円`. When the user imports and chooses the fixture
`acceptance/fixtures/backup/android.backup`, then the user is first asked to
confirm that all data on the device will be replaced; declining leaves
`1,200円` listed and nothing changed, and accepting leaves exactly the file's
ledgers and records.

**AC-E-111** — Given the built app. On Android, its backup rules include the
database and exclude the photos for cloud backup. On iOS, neither the database
nor the photos is excluded from backup.

## 8. Delivery order

Build in this order. Each stage leaves `make check` green and its own criteria
passing, so progress is real even if the product is unfinished.

1. **Foundation** — the on-device database with sync-ready records, ledgers (added, changed to, renamed), isolation, the onboarding tour. AC-B-104, AC-B-107, AC-B-108, AC-B-109, AC-F-102, AC-F-103, AC-F-104, AC-E-101.
2. **Recording money** — categories, transactions, line items, search, income, recurring rules recorded on their business-day-adjusted date. AC-B-201 to AC-B-211, AC-F-201 to AC-F-205, AC-E-201.
3. **Reporting and calendar** — monthly report, daily totals, trend, charts, calendar with the NMD badge. AC-B-301 to AC-B-303, AC-F-301, AC-F-302.
4. **Budget and savings** — budgets, remaining, month close, carry or save. AC-B-401 to AC-B-403, AC-F-401.
5. **Photos and scanning** — photo storage, the document scanner and photo library, on-device text recognition, structuring by the on-device LLM or the rule-based parser, background scanning with its progress, enabling reading from photos, drafts. AC-B-501, AC-B-503 to AC-B-506, AC-B-510, AC-B-511, AC-F-501, AC-F-504, AC-E-501.
6. **Receipts that do not add up** — AC-B-508, AC-F-502.
7. **Needs-review records** — AC-B-509, AC-F-503.
8. **Pace and notifications** — learned pace, alerts, the notification list, local OS notifications, the permission request in the onboarding. AC-B-601 to AC-B-604, AC-F-601, AC-F-602.
9. **Theme** — the look chosen on the device (style, theme colour, brightness, NMD badge, Android dynamic colour). AC-F-701.
10. **Widget** — the home-screen widget on both platforms. AC-B-801, AC-F-801.
11. **Backup** — the OS device backup and the backup file. AC-B-110, AC-B-111, AC-F-110, AC-E-111.

## 9. Definition of done

`make check` is green, `make status` reports every criterion of every stage
passing, and `quality/stage.txt` names the last stage.

import XCTest

/// AC-F-501 — A scanned receipt shows its scan progressing, then an editable
/// draft.
///
/// Given today 2026-02-15, reading from photos enabled, a fake progress
/// surface, and the fixture scanner answering the draft of AC-B-504 (store
/// `セブン-イレブン` confidence 0.95, date 2026-02-14 confidence 0.9, total
/// 1,180 confidence 0.4; おにぎり 380 食費 confidence 0.9, 弁当 800 without a
/// category confidence 0.5), each scan job moving one state on at a time.
/// When the user scans one receipt with the document scanner, then the photo
/// is kept as it is and its scan started, the user is told
/// `1枚の読み取りを受け付けました`, and another scan can be started at once.
/// While the job is queued or running, the progress surface shows it, and it
/// ends when the job completes. The product shows `読み取り中` and then
/// `確認待ち 1件`, and the waiting draft as `セブン-イレブン` `1,180円`;
/// opening it shows every field editable with `店名` `セブン-イレブン`, `合計`
/// marked `要確認` (and `店名` not), and the items おにぎり and 弁当. When 弁当's
/// `金額` becomes 820 and `合計` 1,200 and the draft is confirmed, then
/// `確認待ち` disappears, and the month's transactions list `1,200円` with
/// `セブン-イレブン` with `支出` `1,200円`. Given a document-scanner session of
/// two pages, when it ends, then two scans are started
/// (`2枚の読み取りを受け付けました`); given two photos picked from the photo
/// library, the same.
///
/// The photo kept "as it is" and the saved draft before its confirmation are
/// not visible in the interface; they are the shared logic's (AC-B-501,
/// AC-B-505). What the interface shows of them is asserted here: the count
/// of scans started, and the values the confirmed record carries.
internal final class ScanReceiptAcceptanceTests: XCTestCase {
    /// The launch arguments of every launch here: reading enabled, the fake
    /// progress surface, stepping jobs, and the scanner handing over
    /// `pages` and `picked`.
    private static func arguments(pages: [String], picked: [String]) -> [String] {
        XCUIApplication.scannerArguments(pages: pages, picked: picked) + [
            "-AcceptancePhotoReading", "YES",
            "-UITestFakeProgressSurface", "YES",
            "-UITestJobStepping", "YES",
        ]
    }

    /// Checks the scan just started: told `1枚の読み取りを受け付けました`,
    /// `読み取り中 1件` shown, another scan can start, and the progress
    /// surface shows it.
    private static func checkScanAccepted(_ app: XCUIApplication) {
        expect(app.noticeReads("1枚の読み取りを受け付けました"), "1枚の読み取りを受け付けました と伝えない")
        expect(app.statusReads("読み取り中 1件"), "読み取り中 1件 が出ない: \(app.scanStatus.label)")
        let record: XCUIElement = app.buttons["record-button"]
        expect(record.exists && record.isHittable && record.isEnabled, "読み取り中に次の記録を始められない")
        expect(
            app.progressSurface.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "読み取り中なのに進み具合の表示がない"
        )
    }

    /// Moves the job on until it completes: the progress surface ends and
    /// the status reads `確認待ち 1件`.
    private static func checkJobCompletes(_ app: XCUIApplication) {
        app.stepScanJobs()
        expect(app.statusReads("読み取り中"), "1 段進めただけで 読み取り中 が消えた")
        expect(app.progressSurface.exists, "実行中なのに進み具合の表示が消えた")
        app.stepScanJobs(until: "確認待ち 1件")
        expect(app.statusReads("確認待ち 1件"), "読み取りが終わっても 確認待ち 1件 が出ない: \(app.scanStatus.label)")
        expect(!app.scanStatus.label.contains("読み取り中"), "終わったのに 読み取り中 が残る: \(app.scanStatus.label)")
        expect(app.disappears(app.progressSurface), "読み取りが終わっても進み具合の表示が消えない")
    }

    /// Checks the waiting draft's row and the draft it opens: fields
    /// editable, the items as rows, `合計` marked `要確認` and `店名` not, the two items.
    private static func checkDraftOpens(_ app: XCUIApplication) {
        app.openDraftList()
        let row: XCUIElement = app.firstDraftRow
        expect(
            row.label.contains("セブン-イレブン") && row.label.contains("1,180円"),
            "確認待ちの下書きが セブン-イレブン 1,180円 でない: \(row.label)"
        )
        row.tap()
        expect(
            app.draftField("draft-store").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "下書きが開かない"
        )
        let store: XCUIElement = app.draftField("draft-store")
        expect(store.label == "店名" && store.isEnabled, "店名 が編集できる欄でない")
        expect(app.reads(store, "セブン-イレブン"), "店名 が セブン-イレブン でない")
        let total: XCUIElement = app.draftField("draft-total")
        expect(total.label == "合計" && total.isEnabled, "合計 が編集できる欄でない")
        expect(app.digits(of: total) == "1180", "合計 が 1,180円 でない: \(app.digits(of: total))")
        expect(app.reviewMark("total").label == "要確認", "合計 に 要確認 の印がない")
        expect(!app.reviewMark("store").exists, "店名 に 要確認 の印がある")
        checkItems(app)
    }

    /// Checks the draft's two items as rows, おにぎり 380 in 食費 and 弁当
    /// 800 with no category, and 弁当's sheet with its fields editable.
    private static func checkItems(_ app: XCUIApplication) {
        let names: [String] = ["おにぎり", "弁当"]
        let amounts: [String] = ["380円", "800円"]
        for index in 0..<names.count {
            let row: XCUIElement = app.draftItemRow(index)
            let ordinal: String = "\(index + 1) 番目"
            let found: Bool = row.waitForExistence(timeout: XCUIApplication.screenTimeout)
            expect(found, "\(ordinal)の明細の行がない")
            expect(row.label.contains(names[index]), "\(ordinal)の品名が違う: \(row.label)")
            expect(row.label.contains(amounts[index]), "\(ordinal)の金額が違う: \(row.label)")
        }
        let food: String = app.categoryName(of: app.draftItemRow(0))
        let none: String = app.categoryName(of: app.draftItemRow(1))
        expect(food == "食費", "おにぎり のカテゴリが 食費 でない: \(food)")
        expect(none.isEmpty, "弁当 にカテゴリが付いている: \(none)")
        app.openDraftItem(1)
        let name: XCUIElement = app.draftItemControl("draft-item-name")
        let amount: XCUIElement = app.draftItemControl("draft-item-amount")
        expect(name.label == "品名" && name.isEnabled, "弁当 の 品名 が編集できる欄でない")
        expect(app.reads(name, "弁当"), "弁当 のシートの品名が 弁当 でない")
        expect(amount.label == "金額" && amount.isEnabled, "弁当 の 金額 が編集できる欄でない")
        expect(app.digits(of: amount) == "800", "弁当 のシートの金額が 800円 でない")
        app.draftItemControl("draft-item-cancel").tap()
        expect(
            app.disappears(app.draftItemControl("draft-item-cancel")),
            "× を押しても 明細を直す シートが閉じない"
        )
    }

    /// Corrects 弁当 to 820 and the total to 1,200, confirms, and checks the
    /// month lists `1,200円` with `セブン-イレブン` and `支出` `1,200円`.
    private static func checkConfirmed(_ app: XCUIApplication) {
        app.correctDraftItemAmount(1, to: "820")
        app.replaceText(in: app.draftField("draft-total"), with: "1200")
        let bento: String = app.draftItemRow(1).label
        expect(bento.contains("820円"), "弁当 の金額が 820円 にならない: \(bento)")
        expect(app.digits(of: app.draftField("draft-total")) == "1200", "合計 が 1,200円 にならない")
        app.draftConfirmButton.tap()
        expect(app.disappears(app.draftConfirmButton), "確認しても下書きが閉じない")
        expect(app.disappears(app.scanStatus), "確認しても 確認待ち が消えない")
        let row: XCUIElement = app.transactionRow(
            on: "2026-02-14",
            containing: ["1,200円", "セブン-イレブン"]
        )
        expect(app.reveal(row), "2月14日 の 1,200円 セブン-イレブン が一覧にない")
        expect(app.transactionRowsInOrder().count == 1, "記録が 1 件でない")
        expect(
            app.shows(total: app.expenseTotal, name: "支出", amount: "1,200円"),
            "支出 が 1,200円 でない"
        )
    }

    /// Checks a session of two pages and a pick of two photos each report
    /// `2枚の読み取りを受け付けました` and start two scans.
    private static func checkTwoAtATime(_ app: XCUIApplication) {
        app.startScan(option: "record-option-scan")
        expect(app.noticeReads("2枚の読み取りを受け付けました"), "2ページのスキャンで 2枚の読み取りを受け付けました と伝えない")
        expect(app.statusReads("読み取り中 2件"), "2ページのスキャンで 読み取り中 2件 が出ない: \(app.scanStatus.label)")
        app.startScan(option: "record-option-library")
        expect(app.noticeReads("2枚の読み取りを受け付けました"), "写真 2枚の選択で 2枚の読み取りを受け付けました と伝えない")
        expect(app.statusReads("読み取り中 4件"), "写真 2枚の選択で 読み取り中 4件 が出ない: \(app.scanStatus.label)")
    }

    internal func test_AC_F_501_scanShowsProgressThenEditableDraft() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedScanning(
            arguments: Self.arguments(pages: ["seven-eleven"], picked: [])
        )
        expect(!app.scanStatus.exists, "読み取る前から読み取りの表示がある")
        app.startScan(option: "record-option-scan")
        Self.checkScanAccepted(app)
        Self.checkJobCompletes(app)
        Self.checkDraftOpens(app)
        Self.checkConfirmed(app)

        let paired: XCUIApplication = app.relaunchedScanning(
            arguments: Self.arguments(
                pages: ["seven-eleven", "seven-eleven"],
                picked: ["seven-eleven", "seven-eleven"]
            )
        )
        Self.checkTwoAtATime(paired)
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

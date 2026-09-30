import XCTest

/// AC-E-501 — A user scans a receipt, corrects the draft and confirms it.
///
/// Given the built app, freshly installed, and the fixture scanner handing it
/// `seven-eleven.jpg`. When the user creates `家計`, enables reading from
/// photos, scans a receipt with the document scanner, waits for
/// `確認待ち 1件`, opens the draft, corrects `店名` to `セブンイレブン 新宿店`,
/// 弁当's `金額` to 820 and `合計` to 1,200 and confirms it, then with 2026年2月
/// in view the month's transactions list `1,200円` with `セブンイレブン 新宿店`
/// and `支出` `1,200円`.
///
/// End to end, on the injected clock (§6, determinism in tests): today is
/// 2026-02-15, so 2026年2月 is in view. The scanner answers at once, with no
/// stepping.
internal final class ScanReceiptEndToEndAcceptanceTests: XCTestCase {
    /// Launches freshly installed and creates `家計`, turning reading from
    /// photos on at the onboarding step about it.
    private static func launchedWithReadingEnabled() -> XCUIApplication {
        let app: XCUIApplication = XCUIApplication.launchedForAcceptance(
            arguments: XCUIApplication.resetDataArguments
                + XCUIApplication.todayArguments("2026-02-15")
                + XCUIApplication.scannerArguments(pages: ["seven-eleven"], picked: [])
        )
        expect(
            app.tourStartButton.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿のない端末でツアーの最初の手順が表示されない"
        )
        app.tourStartButton.tap()
        app.advanceTour(to: "photo-reading")
        app.tourPhotoReadingSwitch.tap()
        app.finishTour()
        expect(app.showsLedgerInView(named: "家計"), "家計 が表示中の家計簿でない")
        return app
    }

    internal func test_AC_E_501_scansCorrectsAndConfirmsReceipt() {
        self.continueAfterFailure = false
        let app: XCUIApplication = Self.launchedWithReadingEnabled()

        app.startScan(option: "record-option-scan")
        expect(app.statusReads("確認待ち 1件"), "確認待ち 1件 が出ない: \(app.scanStatus.label)")
        app.openWaitingDraft()
        app.correctDraft(store: "セブンイレブン 新宿店", bentoAmount: "820", total: "1200")
        app.draftConfirmButton.tap()
        expect(app.disappears(app.draftConfirmButton), "確認しても下書きが閉じない")

        let row: XCUIElement = app.transactionRow(
            on: "2026-02-14",
            containing: ["1,200円", "セブンイレブン 新宿店"]
        )
        expect(app.reveal(row), "2月14日 の 1,200円 セブンイレブン 新宿店 が一覧にない")
        expect(app.transactionRowsInOrder().count == 1, "記録が 1 件でない")
        expect(
            app.shows(total: app.expenseTotal, name: "支出", amount: "1,200円"),
            "支出 が 1,200円 でない"
        )
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

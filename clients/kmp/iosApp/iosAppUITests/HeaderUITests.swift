import XCTest

/// The tab header: the ledger-switch menu behind the large title, and the
/// account icon that pushes 設定.
final class HeaderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchedForUITest()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Tapping the large title opens the ledger-switch menu; picking the
    /// other ledger changes the title everywhere it is shown.
    func testLedgerMenuSwitchesLedger() throws {
        app.switchToTab("ホーム")
        let titleMenu = app.buttons["ledger-title-menu"]
        XCTAssertTrue(titleMenu.appears(within: 5), "家計簿切り替えメニューが見つからない")
        XCTAssertTrue(app.staticTexts["家計"].exists)
        titleMenu.tap()

        let secondLedger = app.ledgerMenuRow(named: "サブ家計簿")
        XCTAssertTrue(secondLedger.appears(within: 5), "2つ目の家計簿が見つからない")
        secondLedger.tap()

        XCTAssertTrue(app.staticTexts["サブ家計簿"].appears(within: 5))
    }

    /// The account icon pushes 設定 and the back button returns to the
    /// tab; the floating 記録する button hides on that pushed screen and
    /// shows again after going back.
    ///
    /// The button shows on a main tab's root screen, hides once a screen is
    /// pushed on top of it (e.g. 設定 from ホーム), and shows again once
    /// the user pops back - driven by the tab's own navigation path
    /// (`AppRouter.isRecordButtonVisible`), not merely by which tab is
    /// selected.
    func testSettingsPushedFromAccountIconHidesRecordButtonUntilBack() throws {
        app.switchToTab("ホーム")

        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.appears(within: 5), "ホームのルートで記録ボタンが表示されない")

        app.buttons["account-button"].tap()
        XCTAssertTrue(app.navigationBars["設定"].appears(within: 5))
        XCTAssertFalse(recordButton.exists, "設定 画面でも記録ボタンが表示されている")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["ledger-title-menu"].appears(within: 5))
        XCTAssertTrue(recordButton.appears(within: 5), "ホームへ戻った後に記録ボタンが再表示されない")
    }
}

import XCTest

/// AC-F-103 — A ledger is added, changed to, and renamed.
///
/// Given the ledger `家計` in view. When a ledger named `旅行` is added, then
/// `旅行` is in view, and both `家計` and `旅行` are offered to change to. When
/// `家計` is chosen, then `家計` is in view. When `旅行` is renamed `沖縄旅行`,
/// then `沖縄旅行` is offered in its place. While a name is empty or longer
/// than 20 characters, a ledger cannot be added or renamed with it.
internal final class LedgerSwitchingAcceptanceTests: XCTestCase {
    /// Launches the app freshly installed and creates `家計` through the
    /// tour, leaving it in view.
    private static func launchedWithFirstLedger() -> XCUIApplication {
        let app: XCUIApplication = XCUIApplication.launchedForAcceptance(
            arguments: XCUIApplication.resetDataArguments
        )
        expect(
            app.tourStartButton.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿のない端末でツアーの最初の手順が表示されない"
        )
        app.tourStartButton.tap()
        app.finishTour()
        expect(app.showsLedgerInView(named: "家計"), "家計 が表示中の家計簿でない")
        return app
    }

    internal func test_AC_F_103_addsSwitchesAndRenamesLedger() {
        self.continueAfterFailure = false
        let app: XCUIApplication = Self.launchedWithFirstLedger()

        app.openLedgerSwitcher()
        app.ledgerMenuAddButton.tap()
        let addField: XCUIElement = app.ledgerAddNameField
        expect(
            addField.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿を追加するシートが開かない"
        )
        app.expectNameLimits(field: addField, confirm: app.ledgerAddCreateButton)
        app.replaceText(in: addField, with: "旅行")
        expect(app.ledgerAddCreateButton.isEnabled, "旅行 で家計簿を追加できない")
        app.ledgerAddCreateButton.tap()

        expect(app.showsLedgerInView(named: "旅行"), "追加した 旅行 が表示中の家計簿でない")
        expect(app.offeredLedgerNames() == ["家計", "旅行"].sorted(), "家計 と 旅行 が切り替え先に並ばない")
        app.chooseLedger(named: "家計")
        expect(app.showsLedgerInView(named: "家計"), "家計 を選んでも 家計 が表示中の家計簿にならない")

        app.openSettings()
        app.settingsLedgerRow(named: "旅行").tap()
        let renameField: XCUIElement = app.ledgerRenameNameField
        expect(
            renameField.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿の名前の編集が開かない"
        )
        app.expectNameLimits(field: renameField, confirm: app.ledgerRenameSaveButton)
        app.replaceText(in: renameField, with: "沖縄旅行")
        expect(app.ledgerRenameSaveButton.isEnabled, "沖縄旅行 に変更できない")
        app.ledgerRenameSaveButton.tap()
        expect(
            app.navigationBars["設定"].waitForExistence(timeout: XCUIApplication.screenTimeout),
            "保存しても設定に戻らない"
        )
        app.leaveSettings()

        expect(app.showsLedgerInView(named: "家計"), "名前の変更で表示中の家計簿が 家計 でなくなった")
        expect(app.offeredLedgerNames() == ["家計", "沖縄旅行"].sorted(), "旅行 の代わりに 沖縄旅行 が並ばない")
        app.chooseLedger(named: "家計")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

import XCTest

/// AC-F-102 — A first-time user creates a ledger through the onboarding.
///
/// Given a device with no ledger. When the app is opened, then the tour's
/// first step is shown, its name holding `家計` and the ledger in view
/// reading `家計`. When the name is changed to `我が家`, then the ledger in
/// view reads `我が家` before anything is created. When the ledger is created
/// and the rest of the tour is done, then the ledger `我が家` exists and is
/// the ledger in view. When the app is relaunched, then `我が家` is in view
/// and the tour is not shown.
internal final class OnboardingAcceptanceTests: XCTestCase {
    internal func test_AC_F_102_createsLedgerThroughOnboarding() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedForAcceptance(
            arguments: XCUIApplication.resetDataArguments
        )
        expect(
            app.tourStep("ledger").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿のない端末でツアーの最初の手順が表示されない"
        )
        let nameField: XCUIElement = app.tourLedgerNameField
        expect(nameField.value as? String == "家計", "最初の家計簿の名前が 家計 で埋まっていない")
        expect(app.showsLedgerInView(named: "家計"), "表示中の家計簿が 家計 と読めない")

        app.replaceText(in: nameField, with: "我が家")
        expect(nameField.value as? String == "我が家", "名前が 我が家 にならない")
        expect(app.tourStep("ledger").exists, "名前を入力しただけで家計簿の手順が終わった")
        expect(app.showsLedgerInView(named: "我が家"), "入力中の名前が表示中の家計簿に映らない")

        app.tourStartButton.tap()
        app.finishTour()

        expect(app.showsLedgerInView(named: "我が家"), "作成した 我が家 が表示中の家計簿でない")
        expect(app.offeredLedgerNames() == ["我が家"], "家計簿が 我が家 の 1 つだけでない")
        app.chooseLedger(named: "我が家")

        app.terminate()
        let relaunched: XCUIApplication = XCUIApplication.launchedForAcceptance(arguments: [])

        expect(relaunched.showsLedgerInView(named: "我が家"), "再起動後に 我が家 が表示中の家計簿でない")
        expect(relaunched.tourStaysHidden(), "再起動後にツアーが表示された")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

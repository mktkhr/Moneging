import XCTest

/// AC-E-101 — On first launch, offline, the app opens the onboarding with no
/// sign-in.
///
/// Given the built app, freshly installed, on a device with no network. When
/// it is launched, then the onboarding is shown with no sign-in, and creating
/// `家計` through it leaves `家計` in view.
///
/// "Freshly installed" is the launch argument that empties the on-device
/// database. The network is not cut: v1 makes no network request at all
/// (PRODUCT.md §4, §6), so the test asserts what an offline first launch
/// shows — the tour and no sign-in anywhere on the way through it.
internal final class FirstLaunchAcceptanceTests: XCTestCase {
    internal func test_AC_E_101_opensOnboardingWithoutSignIn() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedForAcceptance(
            arguments: XCUIApplication.resetDataArguments
        )
        expect(
            app.tourStep("ledger").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "初回起動でツアーの最初の手順が表示されない"
        )
        expect(!app.offersSignIn, "初回起動の画面にサインインがある")
        expect(app.tourLedgerNameField.value as? String == "家計", "最初の家計簿の名前が 家計 で埋まっていない")

        app.tourStartButton.tap()
        app.finishTour {
            expect(!app.offersSignIn, "ツアーの手順にサインインがある")
        }

        expect(app.showsLedgerInView(named: "家計"), "作成した 家計 が表示中の家計簿でない")
        expect(!app.offersSignIn, "家計簿の画面にサインインがある")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

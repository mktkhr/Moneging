import XCTest

/// AC-F-104 — The tour resumes where it stopped, ends when skipped, and can
/// be replayed.
///
/// Given a device with no ledger. When `家計` is created through the tour and
/// the app is relaunched before the next step is done, then the tour resumes
/// at that next step, with `家計` in view. When the rest of the tour is
/// skipped, then the tour ends, and a relaunch does not show it. When the
/// tour is replayed from the settings, then it starts at the step after the
/// ledger step, and `家計` is still the only ledger.
///
/// The step after the ledger step is the record step (`tour-step-record`).
internal final class TourResumeAcceptanceTests: XCTestCase {
    internal func test_AC_F_104_resumesSkipsAndReplaysTour() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedForAcceptance(
            arguments: XCUIApplication.resetDataArguments
        )
        expect(
            app.tourStep("ledger").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿のない端末でツアーの最初の手順が表示されない"
        )
        expect(app.tourLedgerNameField.value as? String == "家計", "最初の家計簿の名前が 家計 で埋まっていない")
        app.tourStartButton.tap()
        expect(
            app.tourStep("record").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿の手順の次に記録の手順が表示されない"
        )

        app.terminate()
        let resumed: XCUIApplication = XCUIApplication.launchedForAcceptance(arguments: [])
        expect(
            resumed.tourStep("record").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "再起動後に記録の手順から再開しない"
        )
        expect(!resumed.tourStep("ledger").exists, "再起動後に家計簿の手順が再び表示された")
        expect(resumed.showsLedgerInView(named: "家計"), "再開したツアーで 家計 が表示中の家計簿でない")

        resumed.tourSkipButton.tap()
        expect(resumed.tourStaysHidden(), "スキップしてもツアーが終わらない")

        resumed.terminate()
        let skipped: XCUIApplication = XCUIApplication.launchedForAcceptance(arguments: [])
        expect(skipped.showsLedgerInView(named: "家計"), "スキップ後の再起動で 家計 が表示中の家計簿でない")
        expect(skipped.tourStaysHidden(), "スキップ後の再起動でツアーが表示された")

        skipped.openSettings()
        skipped.swipeUp(toReveal: skipped.settingsReplayTourRow)
        skipped.settingsReplayTourRow.tap()
        expect(
            skipped.tourStep("record").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "設定から見直したツアーが記録の手順から始まらない"
        )
        expect(!skipped.tourStep("ledger").exists, "見直したツアーに家計簿の手順がある")
        expect(!skipped.tourLedgerNameField.exists, "見直したツアーに家計簿の名前の入力欄がある")
        expect(skipped.showsLedgerInView(named: "家計"), "見直したツアーで 家計 が表示中の家計簿でない")

        skipped.tourSkipButton.tap()
        expect(skipped.tourStaysHidden(), "見直したツアーをスキップしても終わらない")
        expect(skipped.offeredLedgerNames() == ["家計"], "ツアーを見直した後の家計簿が 家計 の 1 つだけでない")
        skipped.chooseLedger(named: "家計")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

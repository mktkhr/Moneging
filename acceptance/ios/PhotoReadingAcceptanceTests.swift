import XCTest

/// AC-F-504 — Enabling reading from photos downloads what the device needs,
/// then.
///
/// Given a fresh install and a fake module installer. When, during the
/// onboarding, the user enables reading from photos, then on Android the
/// installer is asked, then, for the ML Kit document scanner and text
/// recognition modules, and for Gemini Nano only when the device reports that
/// it supports it; on iOS nothing is downloaded. Given the user declined
/// during the onboarding, then nothing is downloaded and reading from photos
/// is off; when the user later turns it on, then the same download is
/// requested at that time, and the choice survives a relaunch.
///
/// This is the iOS test: the fake installer's request count stays `0` at
/// every point, and the switch of the onboarding step and of 設定 reads the
/// choice.
internal final class PhotoReadingAcceptanceTests: XCTestCase {
    /// The launch arguments naming the fake module installer.
    private static let fakeInstaller: [String] = ["-UITestModuleInstaller", "fake"]

    /// Launches freshly installed, creates `家計`, and stops at the
    /// onboarding step about reading from photos.
    private static func launchedAtPhotoReadingStep() -> XCUIApplication {
        let app: XCUIApplication = XCUIApplication.launchedForAcceptance(
            arguments: XCUIApplication.resetDataArguments
                + XCUIApplication.todayArguments("2026-02-15") + Self.fakeInstaller
        )
        expect(
            app.tourStartButton.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "家計簿のない端末でツアーの最初の手順が表示されない"
        )
        app.tourStartButton.tap()
        app.advanceTour(to: "photo-reading")
        expect(
            app.tourPhotoReadingSwitch.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "写真から読み取る手順にスイッチがない"
        )
        return app
    }

    /// Whether the fake installer has been asked for nothing so far.
    private static func nothingDownloaded(_ app: XCUIApplication) -> Bool {
        app.moduleInstallRequests.waitForExistence(timeout: XCUIApplication.screenTimeout)
            && app.digits(of: app.moduleInstallRequests) == "0"
    }

    /// Whether 設定 shows reading from photos as `expected` (`1` or `0`).
    private static func settingsShowReading(_ expected: String, in app: XCUIApplication) -> Bool {
        app.openSettings()
        let reading: XCUIElement = app.settingsPhotoReadingSwitch
        app.swipeUp(toReveal: reading)
        return (reading.value as? String) == expected
    }

    /// Enables reading in the onboarding: nothing is downloaded on iOS and
    /// 設定 shows it on.
    private static func checkEnabledInOnboarding() {
        let app: XCUIApplication = Self.launchedAtPhotoReadingStep()
        expect(
            (app.tourPhotoReadingSwitch.value as? String) == "0",
            "写真から読み取るスイッチが最初から入っている"
        )
        app.tourPhotoReadingSwitch.tap()
        expect((app.tourPhotoReadingSwitch.value as? String) == "1", "スイッチを押しても入らない")
        app.finishTour()
        expect(Self.nothingDownloaded(app), "iOS で何かをダウンロードしようとした")
        expect(
            Self.settingsShowReading("1", in: app),
            "オンボーディングで入れた写真の読み取りが 設定 でオンでない"
        )
    }

    /// Declines in the onboarding, then turns it on in 設定 and relaunches.
    private static func checkDeclinedThenEnabledLater() {
        let app: XCUIApplication = Self.launchedAtPhotoReadingStep()
        app.finishTour()
        expect(Self.nothingDownloaded(app), "断ったのに何かをダウンロードしようとした")
        expect(Self.settingsShowReading("0", in: app), "断ったのに写真の読み取りがオフでない")

        app.settingsPhotoReadingSwitch.tap()
        expect(
            (app.settingsPhotoReadingSwitch.value as? String) == "1",
            "後からスイッチを入れても入らない"
        )
        expect(Self.nothingDownloaded(app), "iOS で何かをダウンロードしようとした")

        let relaunched: XCUIApplication = app.relaunchedScanning(arguments: Self.fakeInstaller)
        expect(Self.settingsShowReading("1", in: relaunched), "再起動後に写真の読み取りがオンでない")
        expect(Self.nothingDownloaded(relaunched), "再起動後に何かをダウンロードしようとした")
    }

    internal func test_AC_F_504_enablingReadingFromPhotos() {
        self.continueAfterFailure = false
        Self.checkEnabledInOnboarding()
        Self.checkDeclinedThenEnabledLater()
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

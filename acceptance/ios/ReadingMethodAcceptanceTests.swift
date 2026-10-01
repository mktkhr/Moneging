import XCTest

/// AC-F-505 — A reading method that cannot be used is told before scanning,
/// and each draft says how it was read.
///
/// Given today 2026-02-15, reading from photos enabled, a device whose AI is
/// turned off, and the reading method set to the device's AI. When the user
/// scans a receipt, then before anything is kept or read the user is told
/// `Apple Intelligence が使えません` and offered `AI を使わずに読み取る`,
/// `設定を開く` and `やめる`. Choosing `やめる` keeps no photo and starts no
/// scan. When the user scans again and chooses `AI を使わずに読み取る`, then
/// the receipt is read, and its waiting draft, opened, says
/// `AI を使わずに読み取りました`. In the settings, `読み取りの方法` reads
/// `Apple Intelligence`, and opened, `Apple Intelligence` cannot be chosen and
/// says why, while `AI を使わない` can.
///
/// The photo not kept is not visible in the interface; what is asserted here
/// is that no scan is reported or listed (the shared logic's AC-B-511 holds
/// the rest).
internal final class ReadingMethodAcceptanceTests: XCTestCase {
    /// The launch arguments: reading enabled, one receipt per document-scanner
    /// session, the device's AI turned off, the device's AI chosen.
    private static let arguments: [String] =
        XCUIApplication.scannerArguments(pages: ["seven-eleven"], picked: []) + [
            "-AcceptancePhotoReading", "YES",
            "-UITestDeviceAi", "off",
            "-AcceptanceReadingMethod", "ai",
        ]

    /// Starts a scan and checks the notice that comes before anything is kept
    /// or read: its title and its three choices.
    private static func checkToldBeforeScanning(_ app: XCUIApplication) {
        app.startScan(option: "record-option-scan")
        let notice: XCUIElement = app.readingUnavailableNotice
        expect(
            notice.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "AI が使えないのに、読み取りを始める前の知らせがない"
        )
        expect(
            notice.label == "Apple Intelligence が使えません",
            "知らせが Apple Intelligence が使えません でない: \(notice.label)"
        )
        expect(app.readWithoutAiButton.label == "AI を使わずに読み取る", "AI を使わずに読み取る の選択肢がない")
        expect(app.openReadingSettingsButton.label == "設定を開く", "設定を開く の選択肢がない")
        expect(app.cancelReadingButton.label == "やめる", "やめる の選択肢がない")
        expect(!app.scanStatus.exists, "知らせる前に読み取りが始まっている")
        expect(!app.scanAcceptedNotice.exists, "知らせる前に読み取りを受け付けている")
    }

    /// Chooses `やめる`: the notice goes, and no scan was started.
    private static func checkStoppingStartsNothing(_ app: XCUIApplication) {
        app.cancelReadingButton.tap()
        expect(app.disappears(app.readingUnavailableNotice), "やめる を押しても知らせが閉じない")
        expect(!app.scanStatus.exists, "やめたのに読み取りの表示がある")
        expect(!app.scanAcceptedNotice.exists, "やめたのに読み取りを受け付けた")
        expect(!app.progressSurface.exists, "やめたのに読み取り中の表示がある")
    }

    /// Scans again, reads without AI, and checks the waiting draft says so.
    private static func checkReadWithoutAi(_ app: XCUIApplication) {
        app.startScan(option: "record-option-scan")
        expect(
            app.readWithoutAiButton.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "もう一度読み取ろうとしても知らせが出ない"
        )
        app.readWithoutAiButton.tap()
        expect(app.noticeReads("1枚の読み取りを受け付けました"), "AI を使わずに読み取っても受け付けない")
        expect(
            app.statusReads("確認待ち 1件"),
            "AI を使わずに読み取っても 確認待ち 1件 が出ない: \(app.scanStatus.label)"
        )
        app.openWaitingDraft()
        let method: XCUIElement = app.draftReadingMethod
        expect(
            method.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "下書きにどう読み取ったかの表示がない"
        )
        expect(
            method.label == "AI を使わずに読み取りました",
            "下書きが AI を使わずに読み取りました と言わない: \(method.label)"
        )
    }

    /// Checks the settings' row reads `Apple Intelligence`, and its screen
    /// lets `AI を使わない` be chosen but not `Apple Intelligence`, saying why.
    private static func checkSettings(_ app: XCUIApplication) {
        app.openSettings()
        let row: XCUIElement = app.settingsReadingMethodRow
        app.swipeUp(toReveal: row)
        expect(row.label.contains("読み取りの方法"), "設定の行が 読み取りの方法 でない: \(row.label)")
        expect(
            (row.value as? String) == "Apple Intelligence",
            "読み取りの方法 が Apple Intelligence でない: \(String(describing: row.value))"
        )
        row.tap()
        let aiOption: XCUIElement = app.readingMethodAiOption
        expect(
            aiOption.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "読み取りの方法の画面が開かない"
        )
        expect(
            aiOption.label.contains("Apple Intelligence"),
            "選択肢が Apple Intelligence でない: \(aiOption.label)"
        )
        expect(!aiOption.isEnabled, "使えない Apple Intelligence が選べる")
        let reason: XCUIElement = app.readingMethodAiReason
        expect(reason.exists && !reason.label.isEmpty, "Apple Intelligence が選べない理由が出ない")
        let none: XCUIElement = app.readingMethodNoAiOption
        expect(none.exists && none.label.contains("AI を使わない"), "AI を使わない の選択肢がない")
        expect(none.isEnabled, "AI を使わない が選べない")
    }

    internal func test_AC_F_505_unusableMethodIsToldBeforeScanning() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedScanning(arguments: Self.arguments)
        Self.checkToldBeforeScanning(app)
        Self.checkStoppingStartsNothing(app)
        Self.checkReadWithoutAi(app)

        let relaunched: XCUIApplication = app.relaunchedScanning(arguments: Self.arguments)
        Self.checkSettings(relaunched)
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

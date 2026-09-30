import XCTest

/// The contract the app honours for reading receipts (AC-F-501, AC-F-504,
/// AC-E-501): debug-only launch arguments that stand in for the OS, and the
/// accessibility identifiers of the scan surfaces.
///
/// **Launch arguments** (debug builds only; every one is optional):
/// - `-UITestScannerFixtures <directory>`: the OS document scanner and the
///   photo library picker are replaced by the fixture scanner reading
///   `acceptance/fixtures` at the absolute path `<directory>` (the simulator
///   sees the Mac's file system). Text recognition and structuring are
///   replaced too, so a scan answers the draft beside the picture.
/// - `-UITestScannerPages <names>`: the receipts (`seven-eleven`, comma
///   separated) the document scanner hands over per session, one per page.
/// - `-UITestPickedPhotos <names>`: the receipts the photo library picker
///   hands over, the same way.
/// - `-UITestJobStepping YES`: scan jobs do not advance by themselves; each
///   press of `scan-job-step` moves every unfinished job one state on
///   (`queued → running → succeeded`). Without it the scanner answers at
///   once.
/// - `-UITestFakeProgressSurface YES`: the Live Activity is replaced by an
///   element `progress-surface` on the home screen, present exactly while
///   any job of the ledger in view is queued or running.
/// - `-UITestModuleInstaller fake`: the module installer is replaced by one
///   that downloads nothing and counts its requests, shown by the element
///   `module-install-requests` (on every screen), whose value is the number
///   of requests as digits (`0`).
/// - `-AcceptancePhotoReading YES`: reading from photos is enabled from the
///   start, as if chosen in the onboarding, without asking the installer.
///
/// **Home.** The record sheet (`record-button`) offers `record-option-scan`
/// (the document scanner) and `record-option-library` (the photo library)
/// beside `record-option-manual`. A scan handed over is kept and started at
/// once, and the notice `<N>枚の読み取りを受け付けました` (`scan-accepted-notice`)
/// shows, while `record-button` stays usable. Below the ledger's name, only
/// while any scan is in flight or a draft waits, `scan-status` reads
/// `読み取り中 1件`, `確認待ち 1件` or `読み取り中 1件・確認待ち 2件`; choosing it
/// lists the waiting drafts as `draft-row-<draft id>` rows, labelled with the
/// store and the total (`セブン-イレブン 1,180円`).
///
/// **Draft.** Opening a draft shows its fields, each a text field labelled
/// `店名` (`draft-store`), `日付` (`draft-date`) and `合計` (`draft-total`)
/// and, for item `n` from 0, `品名` (`draft-item-name-<n>`), `金額`
/// (`draft-item-amount-<n>`) and the `カテゴリ` control
/// (`draft-item-category-<n>`, whose value is the category's name, empty for
/// none). A field below the confidence 0.6 has beside it the element
/// `draft-review-<store|date|total|item-<n>>` labelled `要確認`; the others
/// have none. `draft-confirm` saves the corrections and confirms the draft.
///
/// **Onboarding.** The step asking about reading from photos is
/// `tour-step-photo-reading`, with the switch `tour-photo-reading` (value
/// `1` on, `0` off; off unless turned on). 設定 has the same switch as
/// `settings-photo-reading`.
extension XCUIApplication {
    /// The most tour steps stepped through to reach one.
    private static let maxStepsToReach: Int = 10

    /// The most times a job-step button is pressed before giving up.
    private static let maxJobSteps: Int = 5

    /// Seconds a scan is given to be handed over and reported.
    private static let scanTimeout: TimeInterval = 10

    /// The absolute path of `acceptance/fixtures`, found from this file's
    /// place in `acceptance/ios`.
    internal static var fixturesDirectory: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")
            .path
    }

    /// The scan status below the ledger's name (`scan-status`).
    internal var scanStatus: XCUIElement {
        self.descendants(matching: .any)["scan-status"]
    }

    /// The stand-in for the Live Activity (`progress-surface`).
    internal var progressSurface: XCUIElement {
        self.descendants(matching: .any)["progress-surface"]
    }

    /// The button that moves every unfinished scan job one state on
    /// (`scan-job-step`).
    internal var scanJobStepButton: XCUIElement {
        self.buttons["scan-job-step"]
    }

    /// The notice saying how many photos were accepted
    /// (`scan-accepted-notice`).
    internal var scanAcceptedNotice: XCUIElement {
        self.descendants(matching: .any)["scan-accepted-notice"]
    }

    /// The count of requests the fake module installer received
    /// (`module-install-requests`).
    internal var moduleInstallRequests: XCUIElement {
        self.descendants(matching: .any)["module-install-requests"]
    }

    /// The switch of the onboarding step about reading from photos
    /// (`tour-photo-reading`).
    internal var tourPhotoReadingSwitch: XCUIElement {
        self.switches["tour-photo-reading"]
    }

    /// The switch of 設定 for reading from photos (`settings-photo-reading`).
    internal var settingsPhotoReadingSwitch: XCUIElement {
        self.switches["settings-photo-reading"]
    }

    /// The first waiting draft's row (`draft-row-<draft id>`).
    internal var firstDraftRow: XCUIElement {
        self.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'draft-row-'"))
            .firstMatch
    }

    /// The confirm control of the draft shown (`draft-confirm`).
    internal var draftConfirmButton: XCUIElement {
        self.buttons["draft-confirm"]
    }

    /// The launch arguments that replace the OS scanner with the fixture
    /// scanner handing over `pages` from the document scanner and `picked`
    /// from the photo library, each a list of receipt names.
    internal static func scannerArguments(pages: [String], picked: [String]) -> [String] {
        [
            "-UITestScannerFixtures", Self.fixturesDirectory,
            "-UITestScannerPages", pages.joined(separator: ","),
            "-UITestPickedPhotos", picked.joined(separator: ","),
        ]
    }

    /// Launches the app freshly installed with today `2026-02-15` and
    /// `arguments`, and creates `家計` through the tour, leaving it in view.
    internal static func launchedScanning(arguments: [String]) -> XCUIApplication {
        let app: XCUIApplication = Self.launchedForAcceptance(
            arguments: Self.resetDataArguments + Self.todayArguments("2026-02-15") + arguments
        )
        expect(
            app.tourStartButton.waitForExistence(timeout: Self.screenTimeout),
            "家計簿のない端末でツアーの最初の手順が表示されない"
        )
        app.tourStartButton.tap()
        app.finishTour()
        expect(app.showsLedgerInView(named: "家計"), "家計 が表示中の家計簿でない")
        return app
    }

    /// Taps the first button of an OS alert, if one is shown.
    private static func answerNotificationAlert() {
        let springboard: XCUIApplication = XCUIApplication(
            bundleIdentifier: "com.apple.springboard"
        )
        let alert: XCUIElement = springboard.alerts.firstMatch
        if alert.exists {
            alert.buttons.firstMatch.tap()
        }
    }

    /// Terminates this app and launches it again, keeping its data, with
    /// `arguments` (today `2026-02-15` too).
    internal func relaunchedScanning(arguments: [String]) -> XCUIApplication {
        self.terminate()
        let app: XCUIApplication = Self.launchedForAcceptance(
            arguments: Self.todayArguments("2026-02-15") + arguments
        )
        expect(app.showsLedgerInView(named: "家計"), "再起動後に 家計 が表示中の家計簿でない")
        return app
    }

    /// Opens the record sheet and chooses `option` (`record-option-scan` or
    /// `record-option-library`).
    internal func startScan(option: String) {
        let recordButton: XCUIElement = self.buttons["record-button"]
        expect(recordButton.waitForExistence(timeout: Self.screenTimeout), "記録するボタンがない")
        recordButton.tap()
        let choice: XCUIElement = self.descendants(matching: .any)[option]
        expect(choice.waitForExistence(timeout: Self.screenTimeout), "記録するシートに \(option) がない")
        choice.tap()
    }

    /// Whether the accepted notice reads `text` within the scan timeout.
    internal func noticeReads(_ text: String) -> Bool {
        let showing: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", text),
            object: self.scanAcceptedNotice
        )
        return XCTWaiter().wait(for: [showing], timeout: Self.scanTimeout) == .completed
    }

    /// Whether the scan status reads `text` (`読み取り中 1件`) within the scan
    /// timeout.
    internal func statusReads(_ text: String) -> Bool {
        let showing: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", text),
            object: self.scanStatus
        )
        return XCTWaiter().wait(for: [showing], timeout: Self.scanTimeout) == .completed
    }

    /// Presses the job-step button once.
    internal func stepScanJobs() {
        expect(
            self.scanJobStepButton.waitForExistence(timeout: Self.screenTimeout),
            "読み取りを 1 段進めるボタンがない"
        )
        self.scanJobStepButton.tap()
    }

    /// Presses the job-step button until the scan status shows `text`, at
    /// most a few times.
    internal func stepScanJobs(until text: String) {
        for _ in 0..<Self.maxJobSteps where !self.statusReads(text) {
            self.stepScanJobs()
        }
    }

    /// Chooses the scan status, which lists the waiting drafts.
    internal func openDraftList() {
        expect(self.scanStatus.waitForExistence(timeout: Self.screenTimeout), "読み取りの表示がない")
        self.scanStatus.tap()
        expect(
            self.firstDraftRow.waitForExistence(timeout: Self.screenTimeout),
            "確認待ちの下書きが一覧にない"
        )
    }

    /// Lists the waiting drafts and opens the first.
    internal func openWaitingDraft() {
        self.openDraftList()
        self.firstDraftRow.tap()
        expect(
            self.textFields["draft-store"].waitForExistence(timeout: Self.screenTimeout),
            "下書きが開かない"
        )
    }

    /// The text field with the identifier `identifier` on the draft shown.
    internal func draftField(_ identifier: String) -> XCUIElement {
        self.textFields[identifier]
    }

    /// Returns the value of `element` reduced to its digits, so `1,180`
    /// reads `1180`.
    internal func digits(of element: XCUIElement) -> String {
        ((element.value as? String) ?? "").filter(\.isNumber)
    }

    /// The `要確認` mark beside the draft field `field` (`store`, `date`,
    /// `total`, `item-<n>`).
    internal func reviewMark(_ field: String) -> XCUIElement {
        self.descendants(matching: .any)["draft-review-\(field)"]
    }

    /// Corrects the draft shown: the store to `store`, the second item's
    /// amount to `bentoAmount` and the total to `total` (digits).
    internal func correctDraft(store: String, bentoAmount: String, total: String) {
        self.replaceText(in: self.draftField("draft-store"), with: store)
        self.replaceText(in: self.draftField("draft-item-amount-1"), with: bentoAmount)
        self.replaceText(in: self.draftField("draft-total"), with: total)
    }

    /// Taps the tour's next control until the step `step` is shown, and
    /// fails the test if it is not reached.
    internal func advanceTour(to step: String) {
        for _ in 0..<Self.maxStepsToReach where !self.tourStep(step).exists {
            guard self.tourNextButton.waitForExistence(timeout: Self.screenTimeout) else {
                break
            }
            self.tourNextButton.tap()
            Self.answerNotificationAlert()
        }
        expect(
            self.tourStep(step).waitForExistence(timeout: Self.screenTimeout),
            "ツアーに \(step) の手順がない"
        )
    }
}

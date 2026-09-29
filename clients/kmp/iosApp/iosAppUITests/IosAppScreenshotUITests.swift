import XCTest

/// Screenshot-only UI tests: nothing is asserted, each test only attaches
/// PNGs (ホーム, the record sheet, the ledger menu, 設定, カレンダー, 検索,
/// and ホーム again for whatever appearance the simulator is currently
/// running under) for manual review.
///
/// Run by the `iosAppScreenshots` test plan
/// (`iosApp.xcodeproj/xcshareddata/xctestplans/iosAppScreenshots.xctestplan`),
/// not by the default `iosApp` test plan: a screenshot test asserts
/// nothing, so it does not belong in the suite `make check`/CI runs by
/// default, only in an explicit, separate run (e.g. `xcodebuild test
/// -testPlan iosAppScreenshots ...`).
///
/// Screenshots are `XCTAttachment`s with `lifetime = .keepAlways`, attached
/// to the test's own activity - not written to a hard-coded filesystem
/// path. Xcode/`xcresulttool` keeps them in the run's `.xcresult` bundle;
/// extract them from there when reviewing (e.g. `xcrun xcresulttool
/// export attachments`).
final class IosAppScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += XCUIApplication.seededLedgerArguments + XCUIApplication.seededTransactionArguments
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func switchToTab(_ name: String) {
        let tabButton = app.tabBars.buttons[name]
        if tabButton.waitForExistence(timeout: 2) {
            tabButton.tap()
            return
        }

        let collapsedButton = app.tabBars.buttons.firstMatch
        if collapsedButton.waitForExistence(timeout: 3) {
            collapsedButton.tap()
        }

        XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "\(name) タブが見つからない")
        tabButton.tap()
    }

    /// Attaches a PNG screenshot of the current screen, named `name`, kept
    /// in the test run's result bundle regardless of pass/fail.
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Attaches PNG screenshots of ホーム (top and scrolled to its end),
    /// the ledger menu, the record sheet, 設定, カレンダー, and 検索.
    func testCaptureAppScreenshots() throws {
        switchToTab("ホーム")
        attachScreenshot("01-home")

        let lastRow = app.transactionRow(memo: "記録01")
        var scrollAttempts = 0
        while !(lastRow.exists && lastRow.isHittable) && scrollAttempts < 30 {
            app.swipeUp()
            scrollAttempts += 1
        }
        attachScreenshot("01b-home-scrolled-to-bottom")
        app.swipeDown()
        app.swipeDown()

        let titleMenu = app.buttons["ledger-title-menu"]
        XCTAssertTrue(titleMenu.waitForExistence(timeout: 5))
        titleMenu.tap()
        XCTAssertTrue(app.ledgerMenuRow(named: "サブ家計簿").waitForExistence(timeout: 5))
        attachScreenshot("02-ledger-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        let secondLedgerButton = app.ledgerMenuRow(named: "サブ家計簿")
        var menuDismissAttempts = 0
        while secondLedgerButton.exists && menuDismissAttempts < 20 {
            usleep(200_000)
            menuDismissAttempts += 1
        }

        app.buttons["record-button"].tap()
        XCTAssertTrue(app.buttons["record-option-manual"].waitForExistence(timeout: 5))
        attachScreenshot("03-record-sheet")

        // A generic `swipeDown()` was unreliable at dismissing the sheet
        // (its start point does not consistently land inside the sheet's
        // draggable area); dragging from a coordinate inside the sheet to
        // the bottom of the screen is more deterministic.
        let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)

        let manualRow = app.buttons["record-option-manual"]
        var sheetDismissAttempts = 0
        while manualRow.exists && sheetDismissAttempts < 25 {
            usleep(200_000)
            sheetDismissAttempts += 1
        }
        XCTAssertFalse(manualRow.exists, "記録する シートが閉じない")
        // The dismiss animation's dimming overlay can still intercept hits
        // briefly after its elements leave the accessibility tree.
        sleep(1)

        app.buttons["account-button"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        attachScreenshot("04-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        switchToTab("カレンダー")
        XCTAssertTrue(app.descendants(matching: .any)["calendar-tab-root"].waitForExistence(timeout: 5))
        attachScreenshot("05-calendar")

        switchToTab("検索")
        XCTAssertTrue(app.descendants(matching: .any)["search-tab-root"].waitForExistence(timeout: 5))
        attachScreenshot("06-search")
    }

    /// Attaches a PNG screenshot of the 記録する sheet, expanded to the
    /// largest accessibility text size, for manual review of the
    /// scrolling/clamped-height behaviour `FittedSheetModifier` gives it
    /// there.
    func testCaptureRecordSheetScreenshotAtLargestAccessibilityTextSize() throws {
        let axApp = XCUIApplication()
        axApp.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ] + XCUIApplication.seededLedgerArguments
        axApp.launch()
        defer { axApp.terminate() }

        let tabButton = axApp.tabBars.buttons["ホーム"]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()

        axApp.buttons["record-button"].tap()
        XCTAssertTrue(axApp.otherElements["record-sheet-content"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: axApp.screenshot())
        attachment.name = "08-record-sheet-ax-xxxl"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Attaches a PNG screenshot of ホーム in landscape, for manual review of
    /// the floating 記録する button's placement above the tab bar there.
    func testCaptureHomeLandscapeScreenshot() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        switchToTab("ホーム")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["record-button"].waitForExistence(timeout: 5))
        // Wait until the app's own window has actually rotated before
        // capturing, instead of a fixed sleep().
        let window = app.windows.firstMatch
        let isLandscape = NSPredicate { _, _ in window.frame.width > window.frame.height }
        let rotated = expectation(for: isLandscape, evaluatedWith: nil)
        wait(for: [rotated], timeout: 5)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "09-home-landscape"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Attaches a PNG screenshot of ホーム, for manual review of the dark-mode `Theme`.
    ///
    /// The simulator's own appearance (light vs. dark) is outside this
    /// test's control - run under the default (light) appearance, this
    /// simply re-attaches the same screenshot `testCaptureAppScreenshots`
    /// already takes; the verification runbook re-runs this one test alone
    /// with the simulator's appearance forced to dark first
    /// (`xcrun simctl ui <device> appearance dark`), which produces the
    /// actual dark-mode rendering.
    func testCaptureHomeScreenshotForCurrentAppearance() throws {
        switchToTab("ホーム")
        attachScreenshot("07-home-dark")
    }
}

import XCTest

/// Shared launch and navigation helpers for the `iosAppUITests` classes.
///
/// The UI tests are split into one class per concern (tabs, the floating
/// 記録する button, the 記録する sheet, the header): XCTest's parallel
/// testing hands work to its simulator clones one class at a time, so a
/// single class would run on a single clone however many workers exist.
/// Every test launches its own app, so the classes share no state and are
/// safe to run in parallel.
extension XCUIApplication {
    /// The five tabs, in tab bar order.
    static let tabNames: [String] = ["ホーム", "カレンダー", "レポート", "予算", "検索"]

    /// Launch arguments that start the app (debug builds only) as freshly
    /// installed and then with the ledgers 家計 (in view) and サブ家計簿,
    /// the onboarding tour finished (`UITestLaunchData` in the app).
    static let seededLedgerArguments: [String] = ["-UITestSeedLedgers", "YES"]

    /// Launch arguments that also give 家計 24 expenses of today, memos
    /// `記録01` to `記録24` (listed newest first, so `記録01` is last).
    static let seededTransactionArguments: [String] = ["-UITestSeedTransactions", "YES"]

    /// The transaction row of ホーム whose memo is `memo` (`記録05`).
    func transactionRow(memo: String) -> XCUIElement {
        descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'transaction-row-' AND label CONTAINS %@", memo)
        ).firstMatch
    }

    /// The ledger switcher's row for the ledger named `name`.
    func ledgerMenuRow(named name: String) -> XCUIElement {
        buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'ledger-menu-' AND identifier != 'ledger-menu-add' AND label == %@", name)
        ).firstMatch
    }

    /// Launches the app the way every UI test launches it.
    ///
    /// `make ios-ui-test` sets `TEST_RUNNER_UITestDisableAnimations=YES`,
    /// which xcodebuild hands to this test runner as
    /// `UITestDisableAnimations`; it is forwarded to the app as the launch
    /// argument `-UITestDisableAnimations YES` (read through `UserDefaults`
    /// by the debug-only `UITestAnimationSwitch`), so the app switches its
    /// animations off - the same forwarding as
    /// `acceptance/ios/XCUIApplication+Acceptance.swift`.
    ///
    /// Every launch starts past the onboarding, with the ledgers 家計 (in
    /// view) and サブ家計簿: `seededLedgerArguments`.
    static func launchedForUITest(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        if let disableAnimations = ProcessInfo.processInfo.environment["UITestDisableAnimations"] {
            app.launchArguments += ["-UITestDisableAnimations", disableAnimations]
        }
        app.launchArguments += seededLedgerArguments
        app.launchArguments += arguments
        app.launch()
        return app
    }

    /// Taps the named tab. iOS 26's Liquid Glass tab bar collapses to a
    /// single button while the 検索 tab is active; if the target button is
    /// not there, this taps whatever tab bar button currently exists to
    /// expand it back, then taps the target.
    func switchToTab(_ name: String) {
        let tabButton = tabBars.buttons[name]
        if tabButton.exists {
            tabButton.tap()
            return
        }

        let collapsedButton = tabBars.buttons.firstMatch
        if collapsedButton.appears(within: 3) && !tabButton.exists {
            collapsedButton.tap()
        }

        XCTAssertTrue(tabButton.appears(within: 5), "\(name) タブが見つからない")
        tabButton.tap()
    }

    /// Swipes up until `element` is hittable, at most `maxSwipes` times;
    /// returns whether it became hittable.
    @discardableResult
    func swipeUp(until element: XCUIElement, maxSwipes: Int, on surface: XCUIElement? = nil) -> Bool {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            (surface ?? self).swipeUp()
            swipes += 1
        }
        return element.exists && element.isHittable
    }
}

extension XCUIElement {
    /// Whether the element exists now or appears within `timeout` seconds.
    ///
    /// Checks right away first: `waitForExistence(timeout:)` spends about a
    /// second before its first check even when the element is already
    /// there, which added up to most of a UI test's run time.
    func appears(within timeout: TimeInterval) -> Bool {
        exists || waitForExistence(timeout: timeout)
    }
}

/// Polls `element.frame` until it stops changing between consecutive reads
/// (or `timeout` elapses), instead of a fixed `sleep()` - used wherever a
/// test must wait out a presentation/rotation before reading a settled
/// frame.
@discardableResult
func waitForFrameToSettle(
    _ element: XCUIElement,
    requiredStableReads: Int = 3,
    pollInterval: useconds_t = 100_000,
    timeout: TimeInterval = 5,
) -> CGRect {
    let deadline = Date().addingTimeInterval(timeout)
    var previous = element.frame
    var stableReads = 0
    while Date() < deadline {
        usleep(pollInterval)
        let current = element.frame
        if current == previous {
            stableReads += 1
            if stableReads >= requiredStableReads {
                return current
            }
        } else {
            stableReads = 0
        }
        previous = current
    }
    return previous
}

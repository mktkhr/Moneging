import XCTest

/// The contract the app honours for the onboarding tour (AC-F-102, AC-F-104,
/// AC-E-101): a debug-only launch argument that empties the on-device
/// database, and the accessibility identifiers of the tour's callout and of
/// its controls.
///
/// The tour runs over the home screen itself. Every step shows one callout
/// whose root carries `tour-step-<step>`: `tour-step-ledger` (the first
/// ledger's name, which cannot be skipped), then `tour-step-record` (the
/// record button), then the steps after it, whose number the tests do not
/// rely on.
extension XCUIApplication {
    /// Launch arguments that start the app as freshly installed.
    ///
    /// The app, in debug builds only, deletes its on-device database (every
    /// ledger and record, the photos, the remembered ledger in view and the
    /// tour's progress) before it reads anything. A relaunch that must keep
    /// the data omits them.
    internal static let resetDataArguments: [String] = ["-AcceptanceResetData", "YES"]

    /// Seconds to wait for a screen to appear after a launch or a tap.
    internal static let screenTimeout: TimeInterval = 10

    /// Seconds a screen is given to show the tour before the tests conclude
    /// that it does not, and to show the next step after a tap.
    internal static let tourSettleTimeout: TimeInterval = 2

    /// The most steps the tests step through before giving up; the criteria
    /// do not fix the number of steps after the ledger's.
    private static let maxTourSteps: Int = 10

    /// Horizontal position, as a fraction of the field's width, of the tap
    /// that puts the caret at the end of a name.
    private static let fieldEndOffset: CGFloat = 0.95

    /// Vertical middle of a field, as a fraction of its height.
    private static let fieldMiddleOffset: CGFloat = 0.5

    /// The callout of whichever tour step is shown (an identifier starting
    /// with `tour-step-`); it exists only while the tour is shown.
    internal var tourCallout: XCUIElement {
        self.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'tour-step-'"))
            .firstMatch
    }

    /// The text field in the ledger step's callout holding the first
    /// ledger's name (`tour-ledger-name`).
    internal var tourLedgerNameField: XCUIElement {
        self.textFields["tour-ledger-name"]
    }

    /// The ledger step's control that creates the ledger and moves the tour
    /// on (`tour-start`, はじめる).
    internal var tourStartButton: XCUIElement {
        self.buttons["tour-start"]
    }

    /// The control that moves the tour to its next step, or ends it on the
    /// last one (`tour-next`, 次へ).
    internal var tourNextButton: XCUIElement {
        self.buttons["tour-next"]
    }

    /// The control that skips the rest of the tour (`tour-skip`, スキップ).
    internal var tourSkipButton: XCUIElement {
        self.buttons["tour-skip"]
    }

    /// Whether any element on screen offers to sign in or log in, in English
    /// or Japanese, by label or identifier. v1 has no accounts.
    internal var offersSignIn: Bool {
        let predicate: NSPredicate = NSPredicate(
            format: """
                label CONTAINS[c] 'sign in' OR label CONTAINS[c] 'sign-in' \
                OR label CONTAINS[c] 'log in' OR label CONTAINS[c] 'login' \
                OR label CONTAINS 'ログイン' OR label CONTAINS 'サインイン' \
                OR identifier CONTAINS[c] 'sign-in' OR identifier CONTAINS[c] 'signin' \
                OR identifier CONTAINS[c] 'login'
                """
        )
        return self.descendants(matching: .any).matching(predicate).firstMatch.exists
    }

    /// Taps the first button of an OS alert, if one is shown.
    private static func answerSystemAlert() {
        let springboard: XCUIApplication = XCUIApplication(
            bundleIdentifier: "com.apple.springboard"
        )
        let alert: XCUIElement = springboard.alerts.firstMatch
        if alert.exists {
            alert.buttons.firstMatch.tap()
        }
    }

    /// The callout of the tour step `step` (`tour-step-<step>`).
    internal func tourStep(_ step: String) -> XCUIElement {
        self.descendants(matching: .any)["tour-step-\(step)"]
    }

    /// Taps the tour's next control until the tour is gone, so the tests do
    /// not depend on how many steps there are; runs `eachStep` on every step
    /// before leaving it, and fails the test if the tour does not end.
    ///
    /// An OS alert raised on the way (a step asks for permission to post
    /// notifications) is answered with its first button: the criteria here
    /// do not depend on the answer.
    internal func finishTour(eachStep: () -> Void) {
        for _ in 0..<Self.maxTourSteps {
            guard self.tourCallout.waitForExistence(timeout: Self.tourSettleTimeout) else {
                break
            }
            eachStep()
            guard self.tourNextButton.waitForExistence(timeout: Self.screenTimeout) else {
                break
            }
            self.tourNextButton.tap()
            Self.answerSystemAlert()
        }
        expect(self.tourStaysHidden(), "ツアーを最後まで進めても終わらない")
    }

    /// Taps the tour's next control until the tour is gone, checking
    /// nothing on the way (`finishTour(eachStep:)`).
    internal func finishTour() {
        self.finishTour {
            // Nothing to check on each step.
        }
    }

    /// Whether the tour is hidden and stays so: no step is left within the
    /// screen timeout, and none appears within the settle time after that.
    internal func tourStaysHidden() -> Bool {
        let gone: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: self.tourCallout
        )
        guard XCTWaiter().wait(for: [gone], timeout: Self.screenTimeout) == .completed else {
            return false
        }
        return !self.tourCallout.waitForExistence(timeout: Self.tourSettleTimeout)
    }

    /// Replaces the whole text of `field` with `text` (an empty `text`
    /// clears it).
    internal func replaceText(in field: XCUIElement, with text: String) {
        let current: String = (field.value as? String) ?? ""
        let end: CGVector = CGVector(dx: Self.fieldEndOffset, dy: Self.fieldMiddleOffset)
        field.coordinate(withNormalizedOffset: end).tap()
        let deletions: String = String(
            repeating: XCUIKeyboardKey.delete.rawValue,
            count: current.count
        )
        field.typeText(deletions + text)
    }
}

/// Fails the running test with `message` unless `condition` holds.
///
/// The acceptance tests assert through this instead of `XCTAssert*`:
/// SwiftLint's `prefer_nimble` (on under `opt_in_rules: all`) rejects those,
/// and the project has no Nimble. The test cases set `continueAfterFailure`
/// to `false`, so the first failure ends the test.
internal func expect(_ condition: Bool, _ message: String) {
    if !condition {
        XCTFail(message)
    }
}

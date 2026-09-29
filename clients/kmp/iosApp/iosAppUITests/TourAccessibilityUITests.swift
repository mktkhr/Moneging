import XCTest

/// The onboarding tour's callout at the largest accessibility text size. A
/// class of its own because it launches a freshly installed app (the tour
/// shown) instead of the seeded one the other classes launch.
final class TourAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// At the largest accessibility text size the record step's callout
    /// scrolls. Every point of 次へ's frame must move the tour on, even one
    /// outside its capsule (the capsule is tall there, and a touch in its
    /// corner used to be matched to the neighbouring スキップ, ending the
    /// tour); and the next step's callout starts scrolled to its top.
    func testNextAdvancesFromAnyPointOfItsFrameAtLargestAccessibilityTextSize() throws {
        let app = XCUIApplication()
        if let disableAnimations = ProcessInfo.processInfo.environment["UITestDisableAnimations"] {
            app.launchArguments += ["-UITestDisableAnimations", disableAnimations]
        }
        app.launchArguments += [
            "-AcceptanceResetData", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        defer { app.terminate() }

        let start = app.buttons["tour-start"]
        XCTAssertTrue(start.appears(within: 10))
        start.tap()

        let record = app.descendants(matching: .any)["tour-step-record"]
        XCTAssertTrue(record.appears(within: 10))
        let scrollView = record.scrollViews.firstMatch
        let next = app.buttons["tour-next"]
        var swipes = 0
        while next.frame.maxY > scrollView.frame.maxY && swipes < 10 {
            scrollView.swipeUp()
            swipes += 1
        }
        XCTAssertLessThanOrEqual(next.frame.maxY, scrollView.frame.maxY, "AX XXXL で 次へ 全体まで スクロールできない")

        // The frame's bottom-leading corner, next to スキップ: outside the capsule it draws.
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.98)).tap()

        let tabs = app.descendants(matching: .any)["tour-step-tabs"]
        XCTAssertTrue(tabs.appears(within: 5), "次へ の枠の角を押しても次の手順に進まない")
        let title = app.staticTexts["記録はここで振り返れます"]
        XCTAssertTrue(title.appears(within: 5))
        XCTAssertGreaterThanOrEqual(
            title.frame.minY,
            tabs.scrollViews.firstMatch.frame.minY,
            "次の手順の吹き出しが先頭までスクロールされていない",
        )
    }
}

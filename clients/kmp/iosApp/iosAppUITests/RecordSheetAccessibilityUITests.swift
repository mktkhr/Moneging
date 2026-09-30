import XCTest

/// The 記録する sheet at the largest accessibility text size. A class of
/// its own because it launches the app with its own launch arguments.
final class RecordSheetAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// At the largest accessibility text size (`UICTContentSizeCategoryAccessibilityXXXL`),
    /// the 記録する sheet's content is taller than any sheet detent can be
    /// (`FittedSheetModifier` switches to a scrolling, clamped-height
    /// sheet - see that type's doc comment); the title and every row must
    /// still be reachable by scrolling, never merely clipped off-screen.
    func testRecordSheetContentIsReachableAtLargestAccessibilityTextSize() throws {
        let app = XCUIApplication.launchedForUITest(arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        defer { app.terminate() }

        app.switchToTab("ホーム")

        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.appears(within: 5))
        recordButton.tap()

        let sheetContent = app.otherElements["record-sheet-content"]
        XCTAssertTrue(sheetContent.appears(within: 5))

        let title = app.staticTexts["record-sheet-title"]
        XCTAssertTrue(title.appears(within: 5))
        XCTAssertTrue(title.isHittable, "AX XXXL でシートのタイトルに到達できない")

        let rows = [
            app.buttons["record-option-manual"],
            app.buttons["record-option-scan"],
            app.buttons["record-option-library"],
        ]
        for row in rows {
            XCTAssertTrue(
                app.swipeUp(until: row, maxSwipes: 20, on: sheetContent),
                "AX XXXL で \(row.identifier) に到達できない",
            )
        }
    }
}

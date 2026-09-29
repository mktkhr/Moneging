import XCTest

/// The floating 記録する button's placement: it never covers ホーム's last
/// row and never overlaps the tab bar.
final class RecordButtonUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchedForUITest(arguments: XCUIApplication.seededTransactionArguments)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Scrolling ホーム to its very end must never cover the last row with
    /// the floating 記録する button: `MainTabScreen` reserves the button's
    /// own footprint below the scroll content with a `.safeAreaInset` (see
    /// that type's doc comment), so the two frames must never intersect.
    func testHomeLastRowDoesNotIntersectRecordButtonWhenScrolledToEnd() throws {
        app.switchToTab("ホーム")

        let lastRow = app.transactionRow(memo: "記録01")
        XCTAssertTrue(
            app.swipeUp(until: lastRow, maxSwipes: 30),
            "最後までスクロールしても 記録01 の行が見えない",
        )
        // The row can be hittable before the list's end; the list is
        // scrolled on to its very end.
        app.swipeUp()
        app.swipeUp()

        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.appears(within: 5))
        XCTAssertFalse(
            lastRow.frame.intersects(recordButton.frame),
            "最後の行が記録ボタンと重なっている: row=\(lastRow.frame) button=\(recordButton.frame)",
        )
    }

    /// The floating 記録する button floats above the tab bar: its frame
    /// never intersects any tab bar item, including the separate 検索
    /// button, in portrait or landscape.
    func testRecordButtonDoesNotOverlapTabBarItems() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        app.switchToTab("ホーム")

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let recordButton = app.buttons["record-button"]
            XCTAssertTrue(recordButton.appears(within: 5))
            let buttonFrame = waitForFrameToSettle(recordButton)

            let searchButton = app.tabBars.buttons["検索"]
            XCTAssertTrue(searchButton.appears(within: 5), "検索 ボタンが見つからない")
            let tabItems = app.tabBars.buttons.allElementsBoundByIndex
            XCTAssertFalse(tabItems.isEmpty, "タブバーの項目が見つからない")
            for item in tabItems + [searchButton] {
                XCTAssertFalse(
                    buttonFrame.intersects(item.frame),
                    "\(orientation.rawValue): 記録ボタンが \(item.label) と重なっている: button=\(buttonFrame) item=\(item.frame)",
                )
            }
            let tabItemsTop = tabItems.map(\.frame.minY).min() ?? buttonFrame.maxY
            XCTAssertLessThanOrEqual(
                buttonFrame.maxY,
                tabItemsTop,
                "\(orientation.rawValue): 記録ボタンがタブバーより上にない",
            )
        }
    }
}

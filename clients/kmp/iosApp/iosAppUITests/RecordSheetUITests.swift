import XCTest

/// The 記録する sheet opened by the floating button: 手で入力する opens the
/// entry sheet, the rows are in the required order, and the sheet hugs its
/// content.
final class RecordSheetUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchedForUITest()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// The floating 記録する button opens a sheet with three rows:
    /// 手で入力する opens the entry sheet, and the two receipt rows are shown
    /// disabled while reading from photos is off (as it is until turned on).
    func testRecordSheetOpensEntrySheetAndDisablesReceiptRows() throws {
        app.switchToTab("ホーム")

        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.appears(within: 5))
        recordButton.tap()

        XCTAssertFalse(app.buttons["record-option-scan"].isEnabled, "レシートを撮る が押せる")
        XCTAssertFalse(app.buttons["record-option-library"].isEnabled, "写真を選ぶ が押せる")
        let manual = app.buttons["record-option-manual"]
        XCTAssertTrue(manual.appears(within: 5), "手で入力する の行が見つからない")
        manual.tap()

        let amount = app.textFields["entry-amount"]
        XCTAssertTrue(amount.appears(within: 5), "手で入力する で入力のシートが開かない")
        app.buttons["entry-cancel"].tap()
        XCTAssertTrue(recordButton.appears(within: 5), "入力のシートを閉じてもホームに戻らない")
    }

    /// The sheet's three rows render top-to-bottom in the required order
    /// (手で入力する → レシートを撮る → 写真を選ぶ), and the sheet hugs its
    /// own content: no extra empty space below the rows, and no row
    /// compressed to fit.
    ///
    /// Every number here is read from real elements' frames - the
    /// presented sheet's own container and the content inside it - never a
    /// hard-coded constant.
    func testRecordSheetRowsAreInRequiredOrderAndSheetHugsContent() throws {
        app.switchToTab("ホーム")
        app.buttons["record-button"].tap()

        let manualRow = app.buttons["record-option-manual"]
        let receiptRow = app.buttons["record-option-scan"]
        let photoRow = app.buttons["record-option-library"]
        XCTAssertTrue(manualRow.appears(within: 5))
        XCTAssertTrue(receiptRow.exists)
        XCTAssertTrue(photoRow.exists)
        let content = app.otherElements["record-sheet-content"]
        XCTAssertTrue(content.appears(within: 5))
        // Wait for the presentation to settle before reading frames,
        // instead of a fixed sleep().
        let contentFrame = waitForFrameToSettle(content)

        // Required order, top to bottom.
        XCTAssertLessThan(
            manualRow.frame.minY,
            receiptRow.frame.minY,
            "「手で入力する」が「レシートを撮る」より下にある",
        )
        XCTAssertLessThan(
            receiptRow.frame.minY,
            photoRow.frame.minY,
            "「レシートを撮る」が「写真を選ぶ」より下にある",
        )

        // No row is compressed: all three share one height, and the gaps
        // between them match (self-consistency between real elements).
        XCTAssertEqual(
            manualRow.frame.height, receiptRow.frame.height, accuracy: 1, "行の高さが揃っていない（圧縮されている）")
        XCTAssertEqual(
            receiptRow.frame.height, photoRow.frame.height, accuracy: 1, "行の高さが揃っていない（圧縮されている）")
        let gapBetweenFirstTwo = receiptRow.frame.minY - manualRow.frame.maxY
        let gapBetweenLastTwo = photoRow.frame.minY - receiptRow.frame.maxY
        XCTAssertEqual(
            gapBetweenFirstTwo,
            gapBetweenLastTwo,
            accuracy: 1,
            "行の間隔が均一でない（余分な空白がある可能性）",
        )

        // The presented sheet itself: the smallest element that contains
        // `record-sheet-content` but is not the full-screen hierarchy
        // around it.
        let screen = app.windows.firstMatch.frame
        let sheet = try XCTUnwrap(
            app.otherElements
                .containing(.other, identifier: "record-sheet-content")
                .allElementsBoundByIndex
                .map(\.frame)
                .filter { frame in
                    frame.contains(contentFrame) && frame != contentFrame
                        && frame.height < screen.height
                }
                .min { $0.height < $1.height },
            "記録する シートのコンテナが見つからない",
        )

        // The content's own padding is the same on every side, so its top
        // inset inside the sheet equals its leading inset.
        let topInset = contentFrame.minY - sheet.minY
        let leadingInset = contentFrame.minX - sheet.minX
        XCTAssertEqual(topInset, leadingInset, accuracy: 1, "シート上端とコンテンツの間に余分な空白がある")

        // Below the content: that same padding plus the sheet's own bottom
        // safe area (the home indicator) - real chrome, not empty filler.
        // The bottom safe area is measured, not assumed: the tab bar
        // behind the sheet always extends to it, so `screen.maxY` minus
        // the tab bar's own bottom edge is that inset. A few points beyond
        // that (`tolerance`) absorbs measurement/animation jitter, not a
        // guessed constant.
        let tabBar = app.tabBars.firstMatch
        let measuredBottomSafeArea = max(0, screen.maxY - tabBar.frame.maxY)
        let tolerance: CGFloat = 3
        let bottomSpace = sheet.maxY - contentFrame.maxY
        XCTAssertGreaterThanOrEqual(
            bottomSpace,
            topInset - tolerance,
            "コンテンツがシートに収まっていない",
        )
        XCTAssertLessThan(
            bottomSpace - topInset,
            manualRow.frame.height + measuredBottomSafeArea + tolerance,
            "コンテンツの下に行の高さ以上の余分な空白がある",
        )
    }
}

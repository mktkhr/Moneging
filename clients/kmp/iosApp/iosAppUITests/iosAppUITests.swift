import XCTest

/// End-to-end UI tests for the app shell: tab navigation, scroll-position
/// retention across tab switches, the record sheet, the ledger switch
/// menu, the month chip, and 設定.
///
/// Also asserts that a tab root's state object is never recreated when
/// switching tabs (docs/handbook/architecture.md, rule 3), using the
/// debug-only creation counters each tab root exposes (see
/// `TabRootLifecycleMarker`).
///
/// Screenshot-only tests (nothing asserted, PNGs saved for manual review)
/// live separately in `IosAppScreenshotUITests`, run by the
/// `iosAppScreenshots` test plan, not by default (`iosApp` test plan) - see
/// that type's own doc comment.
final class IosAppUITests: XCTestCase {
    private let tabNames = ["ホーム", "カレンダー", "レポート", "予算", "検索"]

    private let creationCountIdentifiers: [(tab: String, identifier: String)] = [
        ("ホーム", "home-creation-count"),
        ("カレンダー", "calendar-creation-count"),
        ("レポート", "report-creation-count"),
        ("予算", "budget-creation-count"),
        ("検索", "search-creation-count"),
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Taps the named tab. iOS 26's Liquid Glass tab bar can momentarily
    /// collapse to a single button after a tab switch; if the target
    /// button is not immediately found, this taps whatever tab bar button
    /// currently exists to expand it back, then retries.
    private func switchToTab(_ name: String, in app: XCUIApplication) {
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

    private func switchToTab(_ name: String) {
        self.switchToTab(name, in: self.app)
    }

    /// Polls `element.frame` until it stops changing between consecutive
    /// reads (or `timeout` elapses), instead of a fixed `sleep()` - used
    /// wherever a test must wait out a presentation/animation before
    /// reading a settled frame.
    @discardableResult
    private func waitForFrameToSettle(
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

    /// Switches through every tab, including the 検索 (search-role) tab.
    func testAllTabsAreSwitchable() throws {
        for name in tabNames {
            switchToTab(name)
        }
    }

    /// Scrolling ホーム down, switching away, and back must not reset the
    /// scroll position or recreate the tab's state object.
    func testHomeScrollPositionAndStateAreRetainedAcrossTabSwitch() throws {
        switchToTab("ホーム")

        let homeCount = app.staticTexts["home-creation-count"]
        XCTAssertTrue(homeCount.waitForExistence(timeout: 5))
        XCTAssertEqual(homeCount.value as? String, "1")

        let targetRow = app.staticTexts["home-recent-record-20"]
        var attempts = 0
        while !(targetRow.exists && targetRow.isHittable) && attempts < 20 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(targetRow.isHittable, "スクロールしても home-recent-record-20 が見えない")
        let frameBeforeSwitch = targetRow.frame

        switchToTab("カレンダー")
        let calendarCount = app.staticTexts["calendar-creation-count"]
        XCTAssertTrue(calendarCount.waitForExistence(timeout: 5))
        XCTAssertEqual(calendarCount.value as? String, "1")

        switchToTab("ホーム")
        XCTAssertTrue(targetRow.waitForExistence(timeout: 5))
        XCTAssertEqual(homeCount.value as? String, "1", "ホームタブの状態オブジェクトが再生成された")
        XCTAssertEqual(targetRow.frame, frameBeforeSwitch, "スクロール位置が保持されていない")
    }

    /// Scrolling ホーム to its very end must never cover the last row with
    /// the floating 記録する button: `MainTabScreen` reserves the button's
    /// own footprint below the scroll content with a `.safeAreaInset` (see
    /// that type's doc comment), so the two frames must never intersect.
    func testHomeLastRowDoesNotIntersectRecordButtonWhenScrolledToEnd() throws {
        switchToTab("ホーム")

        let lastRow = app.staticTexts["home-recent-record-24"]
        var attempts = 0
        while !(lastRow.exists && lastRow.isHittable) && attempts < 30 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(lastRow.isHittable, "最後までスクロールしても home-recent-record-24 が見えない")

        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        XCTAssertFalse(
            lastRow.frame.intersects(recordButton.frame),
            "最後の行が記録ボタンと重なっている: row=\(lastRow.frame) button=\(recordButton.frame)",
        )
    }

    /// The floating 記録する button opens a sheet with three rows, each of
    /// which pushes its own placeholder screen.
    func testRecordSheetOpensAndEachRowNavigates() throws {
        switchToTab("ホーム")

        let options: [(identifier: String, title: String)] = [
            ("manual", "手で入力する"),
            ("photo-pick", "写真を選ぶ"),
            ("receipt-scan", "レシートを撮る"),
        ]

        for option in options {
            let recordButton = app.buttons["record-button"]
            XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
            recordButton.tap()

            let rowButton = app.buttons["record-option-\(option.identifier)"]
            XCTAssertTrue(rowButton.waitForExistence(timeout: 5), "\(option.title) の行が見つからない")
            rowButton.tap()

            XCTAssertTrue(
                app.navigationBars[option.title].waitForExistence(timeout: 5),
                "\(option.title) のプレースホルダー画面が開かない",
            )
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    /// The floating 記録する button hides on a pushed screen, and shows
    /// again after going back.
    ///
    /// Shows on a main tab's root screen, hides once a screen is pushed on
    /// top of it (e.g. 設定 from ホーム), and shows again once the user
    /// pops back - driven by the tab's own navigation path
    /// (`AppRouter.isRecordButtonVisible`), not merely by which tab is
    /// selected.
    func testRecordButtonHiddenOnPushedScreenAndVisibleAfterBack() throws {
        switchToTab("ホーム")

        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "ホームのルートで記録ボタンが表示されない")

        app.buttons["account-button"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        XCTAssertFalse(recordButton.exists, "設定 画面でも記録ボタンが表示されている")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "ホームへ戻った後に記録ボタンが再表示されない")
    }

    /// The 記録する sheet's three rows render top-to-bottom in the required
    /// order: 手で入力する → レシートを撮る → 写真を選ぶ.
    func testRecordSheetRowsAreInRequiredOrder() throws {
        switchToTab("ホーム")
        app.buttons["record-button"].tap()

        let manualRow = app.buttons["record-option-manual"]
        let receiptRow = app.buttons["record-option-receipt-scan"]
        let photoRow = app.buttons["record-option-photo-pick"]
        XCTAssertTrue(manualRow.waitForExistence(timeout: 5))
        XCTAssertTrue(receiptRow.exists)
        XCTAssertTrue(photoRow.exists)

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
    }

    /// The 記録する sheet hugs its own content: no extra empty space below
    /// the rows, and no row compressed to fit.
    ///
    /// Every number here is read from real elements' frames - the
    /// presented sheet's own container and the content inside it - never a
    /// hard-coded constant.
    func testRecordSheetHugsItsOwnContentHeight() throws {
        switchToTab("ホーム")
        app.buttons["record-button"].tap()

        let manualRow = app.buttons["record-option-manual"]
        let receiptRow = app.buttons["record-option-receipt-scan"]
        let photoRow = app.buttons["record-option-photo-pick"]
        XCTAssertTrue(manualRow.waitForExistence(timeout: 5))
        let content = app.otherElements["record-sheet-content"]
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        // Wait for the presentation's spring animation to settle before
        // reading frames, instead of a fixed sleep().
        let contentFrame = waitForFrameToSettle(content)

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

    /// Tapping the large title opens the ledger-switch menu; picking the
    /// other ledger changes the title everywhere it is shown.
    func testLedgerMenuSwitchesLedger() throws {
        switchToTab("ホーム")
        let titleMenu = app.buttons["ledger-title-menu"]
        XCTAssertTrue(titleMenu.waitForExistence(timeout: 5), "家計簿切り替えメニューが見つからない")
        XCTAssertTrue(app.staticTexts["家計"].exists)
        titleMenu.tap()

        let secondLedger = app.buttons["ledger-menu-secondary"]
        XCTAssertTrue(secondLedger.waitForExistence(timeout: 5), "2つ目の家計簿が見つからない")
        secondLedger.tap()

        XCTAssertTrue(app.staticTexts["サブ家計簿"].waitForExistence(timeout: 5))
    }

    /// Changing the month on one tab must be reflected on the others,
    /// since the shared `AppState` publishes a single state.
    func testMonthSelectionIsSharedAcrossTabs() throws {
        switchToTab("ホーム")

        app.buttons["month-chip"].tap()
        let marchOption = app.buttons["3月"]
        XCTAssertTrue(marchOption.waitForExistence(timeout: 5))
        marchOption.tap()

        XCTAssertTrue(app.staticTexts["3月"].waitForExistence(timeout: 5))

        switchToTab("カレンダー")
        XCTAssertTrue(
            app.staticTexts["3月"].waitForExistence(timeout: 5),
            "月の選択がカレンダータブへ反映されていない",
        )
    }

    /// The account icon opens 設定; the back button returns to the tab.
    func testSettingsOpensFromAccountIconAndGoesBack() throws {
        switchToTab("ホーム")

        app.buttons["account-button"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["ledger-title-menu"].waitForExistence(timeout: 5))
    }

    /// Round-tripping through every tab several times must never recreate
    /// any tab root's state object: every creation counter stays at 1.
    ///
    /// Also the evidence for where `lifecycle` state lives on each tab
    /// content view (`HomeTabContent`, `SearchTabContent`, etc., not
    /// `RootView`): 検索 uses `Tab(role: .search)`, once suspected of
    /// reconstructing its content on every activation, but
    /// `search-creation-count` stays "1" here exactly like every other
    /// tab's counter.
    func testTabRootsAreNotRecreatedAcrossManySwitches() throws {
        for _ in 0..<3 {
            for tab in tabNames {
                switchToTab(tab)
            }
        }

        for entry in creationCountIdentifiers {
            switchToTab(entry.tab)
            let marker = app.staticTexts[entry.identifier]
            XCTAssertTrue(marker.waitForExistence(timeout: 5))
            XCTAssertEqual(marker.value as? String, "1", "\(entry.tab) の状態オブジェクトが再生成された")
        }
    }

    /// At the largest accessibility text size (`UICTContentSizeCategoryAccessibilityXXXL`),
    /// the 記録する sheet's content is taller than any sheet detent can be
    /// (`FittedSheetModifier` switches to a scrolling, clamped-height
    /// sheet - see that type's doc comment); the title and every row must
    /// still be reachable by scrolling, never merely clipped off-screen.
    func testRecordSheetContentIsReachableAtLargestAccessibilityTextSize() throws {
        let axApp = XCUIApplication()
        axApp.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        axApp.launch()
        defer { axApp.terminate() }

        switchToTab("ホーム", in: axApp)

        let recordButton = axApp.buttons["record-button"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()

        let sheetContent = axApp.otherElements["record-sheet-content"]
        XCTAssertTrue(sheetContent.waitForExistence(timeout: 5))

        let title = axApp.staticTexts["record-sheet-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(title.isHittable, "AX XXXL でシートのタイトルに到達できない")

        let rows = [
            axApp.buttons["record-option-manual"],
            axApp.buttons["record-option-receipt-scan"],
            axApp.buttons["record-option-photo-pick"],
        ]
        for row in rows {
            var attempts = 0
            while !(row.exists && row.isHittable) && attempts < 20 {
                sheetContent.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(row.isHittable, "AX XXXL で \(row.identifier) に到達できない")
        }
    }
}

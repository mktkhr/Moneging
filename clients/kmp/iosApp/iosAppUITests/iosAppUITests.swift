import XCTest

/// End-to-end UI tests for the app shell: tab navigation, scroll-position
/// retention across tab switches, the record sheet, the ledger switch
/// menu, the month chip, and 設定. Also asserts that a tab root's state
/// object is never recreated when switching tabs
/// (docs/handbook/architecture.md, rule 3), using the debug-only creation
/// counters each tab root exposes (see `TabRootLifecycleMarker`).
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
    /// since the shared `AppViewModel` publishes a single state.
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

    /// Saves PNG screenshots of ホーム, the record sheet, the ledger menu,
    /// 設定, カレンダー, and 検索 for manual review. Written directly to
    /// the host filesystem (the simulator UI test runner process has host
    /// file access), outside the repository.
    func testCaptureAppScreenshots() throws {
        let outputDirectory =
            "/private/tmp/claude-502/-Users-taka-ghq-github-com-mktkhr-Moneging"
            + "/cb07a61f-4e13-4f0b-8b94-7ebb182b377a/scratchpad/shell-shots"
        try FileManager.default.createDirectory(
            atPath: outputDirectory,
            withIntermediateDirectories: true,
        )

        func save(_ name: String) throws {
            let data = app.screenshot().image.pngData()
            let png = try XCTUnwrap(data, "\(name) の PNG 化に失敗した")
            try png.write(to: URL(fileURLWithPath: "\(outputDirectory)/\(name).png"))
        }

        switchToTab("ホーム")
        try save("01-home")

        let titleMenu = app.buttons["ledger-title-menu"]
        XCTAssertTrue(titleMenu.waitForExistence(timeout: 5))
        titleMenu.tap()
        XCTAssertTrue(app.buttons["ledger-menu-secondary"].waitForExistence(timeout: 5))
        try save("02-ledger-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        let secondLedgerButton = app.buttons["ledger-menu-secondary"]
        var menuDismissAttempts = 0
        while secondLedgerButton.exists && menuDismissAttempts < 20 {
            usleep(200_000)
            menuDismissAttempts += 1
        }

        app.buttons["record-button"].tap()
        XCTAssertTrue(app.buttons["record-option-manual"].waitForExistence(timeout: 5))
        try save("03-record-sheet")

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
        try save("04-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        switchToTab("カレンダー")
        XCTAssertTrue(app.staticTexts["calendar-creation-count"].waitForExistence(timeout: 5))
        try save("05-calendar")

        switchToTab("検索")
        XCTAssertTrue(app.staticTexts["search-creation-count"].waitForExistence(timeout: 5))
        try save("06-search")
    }
}

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
}

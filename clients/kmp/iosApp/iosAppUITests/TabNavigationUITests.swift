import XCTest

/// Tab navigation: every tab root keeps its state object across tab
/// switches (docs/handbook/architecture.md, rule 3), ホーム keeps its
/// scroll position, and the selected month is shared by every tab.
///
/// A tab root's state-object creation count is read from the debug-only
/// accessibility value of its `<screen>-tab-root` container (see
/// `TabRootLifecycleHook`).
final class TabNavigationUITests: XCTestCase {
    private let tabRootIdentifiers: [(tab: String, identifier: String)] = [
        ("ホーム", "home-tab-root"),
        ("カレンダー", "calendar-tab-root"),
        ("レポート", "report-tab-root"),
        ("予算", "budget-tab-root"),
        ("検索", "search-tab-root"),
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchedForUITest(arguments: XCUIApplication.seededTransactionArguments)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Every tab, including the 検索 (search-role) tab, is switchable, and
    /// activating a tab again never recreates its root's state object:
    /// each creation counter is 1 on the first visit and still 1 on the
    /// second.
    ///
    /// One round trip is enough to prove it: a tab that rebuilds its state
    /// on activation shows 2 on its second visit. That is exactly what
    /// 検索's `Tab(role: .search)` does - it reconstructs its content on
    /// every activation, unlike the other four, plain tabs - and why
    /// `RootView` holds 検索's `lifecycle` instead of `SearchTabContent`
    /// (see `RootView.searchLifecycle`'s own doc comment) while every other
    /// tab's content view owns its own (see `HomeTabContent.lifecycle`'s
    /// own doc comment).
    func testTabRootsAreNotRecreatedAcrossTabSwitches() throws {
        for visit in ["1回目", "2回目"] {
            for entry in tabRootIdentifiers {
                app.switchToTab(entry.tab)
                let marker = app.descendants(matching: .any)[entry.identifier]
                XCTAssertTrue(marker.appears(within: 5), "\(entry.tab) のルートが表示されない")
                XCTAssertEqual(
                    marker.value as? String,
                    "1",
                    "\(visit)の表示で \(entry.tab) の状態オブジェクトが再生成された",
                )
            }
        }
    }

    /// Scrolling ホーム down, switching away, and back must not reset the
    /// scroll position or recreate the tab's state object.
    func testHomeScrollPositionAndStateAreRetainedAcrossTabSwitch() throws {
        app.switchToTab("ホーム")

        let homeCount = app.descendants(matching: .any)["home-tab-root"]
        XCTAssertTrue(homeCount.appears(within: 5))
        XCTAssertEqual(homeCount.value as? String, "1")

        let targetRow = app.transactionRow(memo: "記録05")
        XCTAssertTrue(
            app.swipeUp(until: targetRow, maxSwipes: 20),
            "スクロールしても 記録05 の行が見えない",
        )
        let frameBeforeSwitch = targetRow.frame

        app.switchToTab("カレンダー")
        let calendarCount = app.descendants(matching: .any)["calendar-tab-root"]
        XCTAssertTrue(calendarCount.appears(within: 5))
        XCTAssertEqual(calendarCount.value as? String, "1")

        app.switchToTab("ホーム")
        XCTAssertTrue(targetRow.appears(within: 5))
        XCTAssertEqual(homeCount.value as? String, "1", "ホームタブの状態オブジェクトが再生成された")
        XCTAssertEqual(targetRow.frame, frameBeforeSwitch, "スクロール位置が保持されていない")
    }

    /// Changing the month on one tab must be reflected on the others,
    /// since the shared `AppState` publishes a single state.
    func testMonthSelectionIsSharedAcrossTabs() throws {
        app.switchToTab("ホーム")

        app.buttons["month-chip"].tap()
        let marchOption = app.buttons["3月"]
        XCTAssertTrue(marchOption.appears(within: 5))
        marchOption.tap()

        XCTAssertTrue(app.staticTexts["3月"].appears(within: 5))

        app.switchToTab("カレンダー")
        XCTAssertTrue(
            app.staticTexts["3月"].appears(within: 5),
            "月の選択がカレンダータブへ反映されていない",
        )
    }
}

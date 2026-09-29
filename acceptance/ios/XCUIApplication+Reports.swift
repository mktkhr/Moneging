import XCTest

/// The contract the app honours for reporting and the calendar (AC-F-301,
/// AC-F-302): the tab bar, the report's share and trend lists, and the
/// calendar's days.
///
/// The tab bar sits at the bottom of the screen with the tabs `カレンダー`
/// and `レポート`. The report shows the month in view: its share as a ring
/// with a list beside it, whose rows are `report-share-<category id>` and
/// whose labels read as text (`食費 3,000円 50%`); then its trend as twelve
/// bars with a list below them, whose rows are `report-trend-<yyyy-MM>` with
/// labels such as `2025年4月 1,000円`. The calendar draws the month in view
/// as weeks starting on Sunday, one cell per day of the month,
/// `calendar-day-<yyyy-MM-dd>`, labelled `2月3日 4,000円` when the day has
/// spending, `2月4日 NMD` when it is a past day with none, and by its date
/// alone (`2月15日`) otherwise. Choosing a day lists its transactions below
/// the calendar, as rows of the same identifier and label as home's
/// (`transaction-row-<yyyy-MM-dd>-<transaction id>`).
extension XCUIApplication {
    /// Opens the tab named `name` (`カレンダー`, `レポート`) of the tab bar.
    internal func openTab(named name: String) {
        let tab: XCUIElement = self.tabBars.buttons[name]
        expect(tab.waitForExistence(timeout: Self.screenTimeout), "下のタブバーに \(name) がない")
        tab.tap()
    }

    /// The rows of the report's share list, in list order.
    internal func reportShareRows() -> [ScrolledRow] {
        self.collectRows(self.rows(identifiedBy: "report-share-"))
    }

    /// The rows of the report's trend list, in list order.
    internal func reportTrendRows() -> [ScrolledRow] {
        self.collectRows(self.rows(identifiedBy: "report-trend-"))
    }

    /// The transaction rows listed below the calendar for the chosen day, in
    /// list order.
    internal func chosenDayTransactionRows() -> [ScrolledRow] {
        self.collectRows(self.rows(identifiedBy: "transaction-row-"))
    }

    /// The calendar's cell for the day `isoDate` (`2026-02-03`).
    internal func calendarDay(_ isoDate: String) -> XCUIElement {
        self.descendants(matching: .any)["calendar-day-\(isoDate)"]
    }

    /// Records, through the entry sheet, an expense of `amount` (typed as
    /// digits) in the category named `category`, at the store `store`
    /// (`entry-store`), on the date the sheet proposes.
    internal func recordExpense(amount: String, category: String, store: String) {
        self.openEntrySheet()
        self.tapCategoryTile(named: category)
        let field: XCUIElement = self.textFields["entry-store"]
        expect(field.waitForExistence(timeout: Self.screenTimeout), "店名の欄がない")
        field.tap()
        field.typeText(store + "\n")
        self.replaceAmount(with: amount)
        self.entrySaveButton.tap()
        expect(self.disappears(self.entryAmountField), "保存しても入力のシートが閉じない")
    }

    /// Every element whose identifier starts with `prefix`.
    private func rows(identifiedBy prefix: String) -> XCUIElementQuery {
        self.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }
}

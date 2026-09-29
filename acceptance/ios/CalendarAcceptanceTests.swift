import XCTest

/// AC-F-302 — The calendar shows daily totals and an NMD badge on past zero
/// days.
///
/// Given a ledger created on 2026-02-02, 2026-02 with 4,000 on the 3rd
/// (1,500 食費 スーパー and 2,500 日用品), 800 on the 10th, and nothing on
/// the 1st, the 4th, the 15th and the 20th, with today 2026-02-15. When the
/// month's calendar is viewed, then the 3rd shows 4,000 (`2月3日 4,000円`),
/// the 4th shows the NMD badge (`2月4日 NMD`), and the 1st (before the
/// ledger), the 15th and the 20th do not. When the 3rd is chosen, then its
/// two transactions are listed and the 10th's is not.
///
/// The ledger is built through the interface: created with today
/// 2026-02-02, then each transaction recorded on its own date by
/// relaunching with that date as today (`-AcceptanceToday`) and keeping the
/// date the entry sheet proposes.
internal final class CalendarAcceptanceTests: XCTestCase {
    /// Creates the ledger on 2026-02-02, records the criterion's
    /// transactions and returns the app on 2026-02-15.
    private static func launchedWithCalendarData() -> XCUIApplication {
        let created: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-02-02")

        let third: XCUIApplication = created.relaunched(today: "2026-02-03")
        third.recordExpense(amount: "1500", category: "食費", store: "スーパー")
        third.recordExpense(amount: "2500", category: "日用品", memo: nil)

        let tenth: XCUIApplication = third.relaunched(today: "2026-02-10")
        tenth.recordExpense(amount: "800", category: "食費", memo: nil)

        return tenth.relaunched(today: "2026-02-15")
    }

    /// Whether the calendar's cell for `isoDate` exists and its label reads
    /// exactly `label`.
    private static func dayReads(
        _ app: XCUIApplication,
        _ isoDate: String,
        _ label: String
    ) -> Bool {
        let cell: XCUIElement = app.calendarDay(isoDate)
        return app.reveal(cell) && cell.label == label
    }

    /// Whether the calendar's cell for `isoDate` exists and does not show
    /// the NMD badge.
    private static func dayHasNoBadge(_ app: XCUIApplication, _ isoDate: String) -> Bool {
        let cell: XCUIElement = app.calendarDay(isoDate)
        return app.reveal(cell) && !cell.label.contains("NMD")
    }

    internal func test_AC_F_302_showsDailyTotalsAndNmdBadge() {
        self.continueAfterFailure = false
        let app: XCUIApplication = Self.launchedWithCalendarData()
        app.openTab(named: "カレンダー")

        expect(Self.dayReads(app, "2026-02-03", "2月3日 4,000円"), "3日 が 2月3日 4,000円 でない")
        expect(Self.dayReads(app, "2026-02-04", "2月4日 NMD"), "4日 が 2月4日 NMD でない")
        expect(Self.dayHasNoBadge(app, "2026-02-01"), "家計簿を作る前の 1日 に NMD が付いている")
        expect(Self.dayHasNoBadge(app, "2026-02-15"), "今日 15日 に NMD が付いている")
        expect(Self.dayHasNoBadge(app, "2026-02-20"), "未来の 20日 に NMD が付いている")

        app.calendarDay("2026-02-03").tap()
        let rows: [ScrolledRow] = app.chosenDayTransactionRows()
        expect(rows.count == 2, "3日 を選んで取引が 2 件並ばない: \(rows.map(\.label))")
        expect(
            rows.contains { row in
                row.identifier.hasPrefix("transaction-row-2026-02-03-")
                    && ["1,500円", "食費", "スーパー"].allSatisfy { row.label.contains($0) }
            }
                && rows.contains { row in
                    row.identifier.hasPrefix("transaction-row-2026-02-03-")
                        && ["2,500円", "日用品"].allSatisfy { row.label.contains($0) }
                },
            "3日 の取引が 1,500円 食費 スーパー と 2,500円 日用品 でない: \(rows.map(\.label))"
        )
        expect(
            !rows.contains { row in row.label.contains("800円") },
            "10日 の 800円 が 3日 の一覧にある"
        )
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

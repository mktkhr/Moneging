import XCTest

/// AC-F-301 — Monthly totals by category are charted.
///
/// Given 2026-02 with 1,000 and 2,000 食費, 3,000 交通費 and an income of
/// 5,000, 1,000 食費 in 2025-04, and today 2026-02-15. When the month's
/// report is viewed, then the month's share lists 食費 `3,000円` `50%` and
/// 交通費 `3,000円` `50%` and nothing else, and the trend lists the twelve
/// months from `2025年3月` to `2026年2月`, with `2026年2月` `6,000円`,
/// `2025年4月` `1,000円` and the others `0円`.
///
/// The ledger is built through the interface: the April 2025 expense is
/// recorded with that date as today (`-AcceptanceToday`), the rest on
/// 2026-02-15, each on the date the entry sheet proposes.
internal final class ReportAcceptanceTests: XCTestCase {
    /// The trend's rows, `label` by month, as the criterion states them.
    private static let expectedTrend: [String] = [
        "2025年3月 0円", "2025年4月 1,000円", "2025年5月 0円", "2025年6月 0円",
        "2025年7月 0円", "2025年8月 0円", "2025年9月 0円", "2025年10月 0円",
        "2025年11月 0円", "2025年12月 0円", "2026年1月 0円", "2026年2月 6,000円",
    ]

    /// Records the criterion's transactions and returns the app on
    /// 2026-02-15.
    private static func launchedWithReportData() -> XCUIApplication {
        let april: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2025-04-15")
        april.recordExpense(amount: "1000", category: "食費", memo: nil)

        let february: XCUIApplication = april.relaunched(today: "2026-02-15")
        february.recordExpense(amount: "1000", category: "食費", memo: nil)
        february.recordExpense(amount: "2000", category: "食費", memo: nil)
        february.recordExpense(amount: "3000", category: "交通費", memo: nil)
        february.recordIncome(amount: "5000")
        return february
    }

    internal func test_AC_F_301_chartsMonthlyTotalsByCategory() {
        self.continueAfterFailure = false
        let app: XCUIApplication = Self.launchedWithReportData()
        app.openTab(named: "レポート")

        let share: [String] = app.reportShareRows().map(\.label)
        expect(
            Set(share) == ["食費 3,000円 50%", "交通費 3,000円 50%"] && share.count == 2,
            "2月 の内訳が 食費 3,000円 50% と 交通費 3,000円 50% の 2 件でない: \(share)"
        )

        let trend: [String] = app.reportTrendRows().map(\.label)
        expect(
            trend == Self.expectedTrend,
            "推移が 2025年3月 から 2026年2月 の 12 か月で、2026年2月 6,000円・2025年4月 1,000円・"
                + "ほかは 0円 でない: \(trend)"
        )
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

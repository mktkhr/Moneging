import XCTest

/// AC-E-201 — A user records an expense and sees it in the month's list and
/// total.
///
/// Given the built app, freshly installed. When the user creates `家計`
/// through the onboarding and records an expense of 1,200 食費, then the
/// month's transactions list `1,200円` 食費 with `支出` `1,200円`, and after
/// the app is terminated and relaunched both are still shown.
///
/// End to end, on the injected clock (PRODUCT.md §6): today is 2026-02-15
/// on both launches, so the month in view cannot change between them. The
/// relaunch keeps the data (no reset argument).
internal final class FirstExpenseAcceptanceTests: XCTestCase {
    /// Today on both launches.
    private static let today: String = "2026-02-15"

    /// Whether `app` lists exactly one transaction, `1,200円` 食費 on
    /// 2月15日, with `支出` `1,200円`.
    private static func showsTheExpense(_ app: XCUIApplication) -> Bool {
        let row: XCUIElement = app.transactionRow(on: Self.today, containing: ["1,200円", "食費"])
        guard app.reveal(row) else {
            return false
        }
        let rows: [ScrolledRow] = app.transactionRowsInOrder()
        return rows.count == 1
            && rows.allSatisfy { listed in
                listed.label.contains("1,200円") && listed.label.contains("食費")
            }
            && app.shows(total: app.expenseTotal, name: "支出", amount: "1,200円")
    }

    internal func test_AC_E_201_recordsExpenseAndKeepsIt() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedWithKakei(today: Self.today)
        expect(app.transactionRowsInOrder().isEmpty, "作成したばかりの 家計 に記録がある")

        app.recordExpense(amount: "1200", category: "食費", memo: nil)
        expect(Self.showsTheExpense(app), "記録した 1,200円 食費 と 支出 1,200円 が表示されない")

        let relaunched: XCUIApplication = app.relaunched(today: Self.today)
        expect(Self.showsTheExpense(relaunched), "再起動後に 1,200円 食費 と 支出 1,200円 が表示されない")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

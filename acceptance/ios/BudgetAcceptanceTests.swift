import XCTest

/// AC-F-401 — Remaining budget per category is shown.
///
/// Given today 2026-02-15, a whole-month budget of 50,000 and a 食費 budget
/// of 30,000 from 2026-02, and expenses of 18,500 食費 and 3,000 交通費. When
/// the month's budgets are viewed, then the whole month shows `28,500円`
/// remaining with `予算 50,000円`, 食費 shows `残り 11,500円` `予算 30,000円`,
/// and 交通費 shows `3,000円` without a budget. When the user adds a 交通費
/// budget of 5,000 from 2026-02, then 交通費 shows `残り 2,000円`
/// `予算 5,000円`.
///
/// The budgets and expenses are made through the interface, on 2026-02-15.
internal final class BudgetAcceptanceTests: XCTestCase {
    internal func test_AC_F_401_showsRemainingBudgetPerCategory() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-02-15")
        app.recordExpense(amount: "18500", category: "食費", memo: nil)
        app.recordExpense(amount: "3000", category: "交通費", memo: nil)
        app.openTab(named: "予算")
        app.setBudget(amount: "50000", category: nil)
        app.setBudget(amount: "30000", category: "食費")

        expect(
            app.budgetReads(app.budgetWholeRow, ["28,500円", "予算 50,000円"]),
            "月全体が 28,500円 と 予算 50,000円 でない: \(app.budgetWholeRow.label)"
        )
        let food: XCUIElement = app.budgetRow(named: "食費")
        expect(
            app.budgetReads(food, ["残り 11,500円", "予算 30,000円"]),
            "食費 が 残り 11,500円 予算 30,000円 でない: \(food.label)"
        )
        let transport: XCUIElement = app.budgetRow(named: "交通費")
        expect(
            app.budgetReads(transport, ["3,000円"]),
            "予算のない 交通費 が 3,000円 でない: \(transport.label)"
        )
        expect(
            !transport.label.contains("予算") && !transport.label.contains("残り"),
            "予算のない 交通費 に 予算 や 残り が出ている: \(transport.label)"
        )

        app.setBudget(amount: "5000", category: "交通費")
        expect(
            app.budgetReads(transport, ["残り 2,000円", "予算 5,000円"]),
            "交通費 が 残り 2,000円 予算 5,000円 でない: \(transport.label)"
        )
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

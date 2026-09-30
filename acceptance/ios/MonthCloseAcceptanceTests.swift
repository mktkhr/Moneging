import XCTest

/// AC-F-402 — A month is closed from the interface, its leftover saved.
///
/// Given today 2026-03-05, the policy `carry`, a 食費 budget of 30,000 from
/// 2026-02 and 18,500 食費 spent in 2026-02. When the budgets are viewed,
/// then `2月を締めましょう` is offered. When the user closes 2026-02, chooses
/// `貯金にする` and confirms, then the offer is gone, the savings read
/// `貯金 11,500円`, and 2026-03's 食費 shows `残り 30,000円` `予算 30,000円`.
///
/// The budget and the expense are made through the interface on 2026-02-15;
/// the app is then launched again on 2026-03-05, the policy being `carry`
/// as in every new ledger.
internal final class MonthCloseAcceptanceTests: XCTestCase {
    internal func test_AC_F_402_closesMonthSavingLeftover() {
        self.continueAfterFailure = false
        let february: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-02-15")
        february.recordExpense(amount: "18500", category: "食費", memo: nil)
        february.openTab(named: "予算")
        february.setBudget(amount: "30000", category: "食費")

        let app: XCUIApplication = february.relaunched(today: "2026-03-05")
        app.openTab(named: "予算")
        expect(
            app.budgetCloseOffer.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "3月5日 に 2月を締めましょう が出ない"
        )
        expect(
            app.budgetReads(app.budgetCloseOffer, ["2月を締めましょう"]),
            "締める案内が 2月を締めましょう でない: \(app.budgetCloseOffer.label)"
        )

        app.closeOfferedMonthSavingLeftover()

        expect(app.disappears(app.budgetCloseOffer), "締めても 2月を締めましょう が消えない")
        expect(
            app.budgetReads(app.budgetSavings, ["貯金 11,500円"]),
            "貯金が 貯金 11,500円 でない: \(app.budgetSavings.label)"
        )
        let food: XCUIElement = app.budgetRow(named: "食費")
        expect(
            app.budgetReads(food, ["残り 30,000円", "予算 30,000円"]),
            "3月の 食費 が 残り 30,000円 予算 30,000円 でない: \(food.label)"
        )
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

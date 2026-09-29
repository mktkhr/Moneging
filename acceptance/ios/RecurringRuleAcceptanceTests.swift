import XCTest

/// AC-F-204 — A recurring rule is set up and records itself when its date
/// comes.
///
/// Given today 2026-02-26 and a ledger with no recurring rules. When the user
/// adds a rule with amount `80000`, category 住居, day `25`,
/// `土日祝なら翌平日` and start month 2026-02, then it is listed as
/// `毎月25日 80,000円 住居` with `土日祝なら翌平日` and `次回 3月25日（水）`,
/// and, with nothing more done, the month's transactions list `80,000円` 住居
/// marked `定期` on 2026-02-25. When the user adds an income rule of `250000`
/// on the month's last day, then it is listed as `毎月末日 250,000円 収入` and
/// no category is asked for.
///
/// The start month is left as the sheet proposes it, the month of today
/// (`2026年2月`); the test checks that it reads so.
internal final class RecurringRuleAcceptanceTests: XCTestCase {
    internal func test_AC_F_204_setsUpRecurringRules() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-02-26")
        app.openRecurringRules()
        expect(app.recurringRuleRows().isEmpty, "定期のない家計簿に定期が並んでいる")

        self.addRentRule(app: app)
        let rent: XCUIElement = app.recurringRuleRow(
            containing: ["毎月25日 80,000円 住居", "土日祝なら翌平日", "次回 3月25日（水）"]
        )
        expect(
            app.reveal(rent),
            "定期が 毎月25日 80,000円 住居・土日祝なら翌平日・次回 3月25日（水） と並ばない"
        )

        self.addSalaryRule(app: app)
        let salary: XCUIElement = app.recurringRuleRow(containing: ["毎月末日 250,000円 収入"])
        expect(
            app.reveal(salary),
            "収入の定期が 毎月末日 250,000円 収入 と並ばない"
        )

        app.leaveLedgerSettings()
        let recorded: XCUIElement = app.transactionRow(
            on: "2026-02-25",
            containing: ["80,000円", "住居", "定期"]
        )
        expect(
            app.reveal(recorded),
            "2月25日 に 80,000円 住居 が 定期 の印付きで記録されていない"
        )
        expect(
            app.transactionRowsInOrder().count == 1,
            "2月 の記録が 2月25日 の 住居 だけでない（月末の収入は 2月28日 でまだ来ていない）"
        )
    }

    /// Adds 80,000円 住居 on day 25, moved to the next weekday, from the
    /// month the sheet proposes (2026年2月).
    private func addRentRule(app: XCUIApplication) {
        app.openRecurringRuleSheet()
        expect(app.recurringDirection.buttons["支出"].isSelected, "定期のシートが 支出 で始まらない")
        expect(app.reads(app.recurringStartMonth, "2026年2月"), "定期の開始が 2026年2月 でない")
        app.tapCategoryTile(named: "住居")
        app.recurringAdjustment.buttons["翌平日"].tap()
        app.replaceText(in: app.recurringDayField, with: "25")
        app.replaceText(in: app.recurringAmountField, with: "80000")
        app.recurringSaveButton.tap()
        expect(app.disappears(app.recurringAmountField), "保存しても定期のシートが閉じない")
    }

    /// Adds an income of 250,000円 on the month's last day, checking that no
    /// category is asked for.
    private func addSalaryRule(app: XCUIApplication) {
        app.openRecurringRuleSheet()
        app.recurringDirection.buttons["収入"].tap()
        expect(app.collectRowsInSheet(app.categoryTiles).isEmpty, "収入の定期で分類が求められる")
        app.recurringMonthEndButton.tap()
        app.replaceText(in: app.recurringAmountField, with: "250000")
        app.recurringSaveButton.tap()
        expect(app.disappears(app.recurringAmountField), "保存しても定期のシートが閉じない")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

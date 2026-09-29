import XCTest

/// AC-F-205 — A recurring rule is changed, ended, resumed and deleted from the
/// interface.
///
/// Given today 2026-02-26 and a ledger with the rule
/// `毎月25日 80,000円 住居`, `土日祝なら翌平日`, from 2026-02, that has recorded
/// its 2026-02-25 transaction. When the user opens the rule and changes its
/// amount to `85000`, then it is listed as `毎月25日 85,000円 住居`, and the
/// month's transactions still list `80,000円` 住居 marked `定期`. When the user
/// opens it and chooses `この定期を終了`, then it is listed under `終了した定期`
/// with `2026年2月まで` and no `次回`. When the user opens it and sets `終了`
/// back to `なし`, then it is listed above `終了した定期` again with
/// `次回 3月25日（水）`. When the user opens it, chooses `削除` and confirms,
/// then no rule is listed, and the month's transactions still list `80,000円`
/// 住居 marked `定期`.
///
/// The premise rule is added through the interface, as AC-F-204 does.
internal final class RecurringRuleEditAcceptanceTests: XCTestCase {
    internal func test_AC_F_205_changesEndsResumesAndDeletesRecurringRule() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-02-26")
        app.openRecurringRules()
        self.addRentRule(app: app)

        self.changeAmount(app: app)
        self.expectRecordedRentUntouched(app: app)

        app.openRecurringRules()
        self.endRule(app: app)
        self.resumeRule(app: app)
        self.deleteRule(app: app)
        app.leaveLedgerSettings()
        self.expectRecordedRentUntouched(app: app)
    }

    /// Adds 80,000円 住居 on day 25, moved to the next weekday, from the
    /// month the sheet proposes (2026年2月).
    private func addRentRule(app: XCUIApplication) {
        app.openRecurringRuleSheet()
        app.tapCategoryTile(named: "住居")
        app.recurringAdjustment.buttons["翌平日"].tap()
        app.replaceText(in: app.recurringDayField, with: "25")
        app.replaceText(in: app.recurringAmountField, with: "80000")
        app.recurringSaveButton.tap()
        expect(app.disappears(app.recurringAmountField), "保存しても定期のシートが閉じない")
        expect(
            app.reveal(app.recurringRuleRow(containing: ["毎月25日 80,000円 住居"])),
            "前提の定期が 毎月25日 80,000円 住居 と並ばない"
        )
    }

    /// Changes the amount to 85,000円 and checks the rule is listed so.
    private func changeAmount(app: XCUIApplication) {
        app.openRecurringRule(containing: ["毎月25日 80,000円 住居"])
        app.replaceText(in: app.recurringAmountField, with: "85000")
        app.recurringSaveButton.tap()
        expect(app.disappears(app.recurringAmountField), "保存しても定期のシートが閉じない")
        let changed: XCUIElement = app.recurringRuleRow(containing: ["毎月25日 85,000円 住居"])
        expect(app.reveal(changed), "金額を変えた定期が 毎月25日 85,000円 住居 と並ばない")
        let labels: [String] = app.recurringListInOrder().map(\.label)
        expect(
            !labels.contains { label in label.contains("80,000円") },
            "80,000円 の定期が残っている: \(labels)"
        )
    }

    /// Goes home and checks the month still lists the recorded 80,000円 住居
    /// marked 定期 on 2026-02-25, and nothing else, then returns to home's
    /// settings entry point for the caller.
    private func expectRecordedRentUntouched(app: XCUIApplication) {
        if app.navigationBars["毎月の定期"].exists {
            app.leaveLedgerSettings()
        }
        let recorded: XCUIElement = app.transactionRow(
            on: "2026-02-25",
            containing: ["80,000円", "住居", "定期"]
        )
        expect(app.reveal(recorded), "2月25日 の 80,000円 住居 が 定期 の印付きで残っていない")
        let rows: [ScrolledRow] = app.transactionRowsInOrder()
        expect(rows.count == 1, "2月 の記録が 80,000円 住居 の 1 件だけでない: \(rows.map(\.label))")
        expect(
            !rows.contains { row in row.label.contains("85,000円") },
            "記録済みの取引が 85,000円 に変わった"
        )
    }

    /// Ends the rule, and checks it is listed under 終了した定期 with
    /// 2026年2月まで and no 次回.
    private func endRule(app: XCUIApplication) {
        app.openRecurringRule(containing: ["毎月25日 85,000円 住居"])
        expect(app.recurringEndButton.exists, "定期のシートに この定期を終了 がない")
        app.recurringEndButton.tap()
        expect(app.disappears(app.recurringAmountField), "終了しても定期のシートが閉じない")

        let ended: XCUIElement = app.recurringRuleRow(
            containing: ["毎月25日 85,000円 住居", "2026年2月まで"]
        )
        expect(app.reveal(ended), "終了した定期が 2026年2月まで と並ばない")
        expect(!ended.label.contains("次回"), "終了した定期に 次回 が読める: \(ended.label)")
        let order: [ScrolledRow] = app.recurringListInOrder()
        expect(order.count == 2, "終了後の一覧が 終了した定期 の見出しと定期 1 件でない: \(order.map(\.label))")
        expect(
            order.first?.identifier == "recurring-ended-header"
                && order.first?.label.contains("終了した定期") == true,
            "終了した定期 が見出しの下に並ばない: \(order.map(\.label))"
        )
    }

    /// Sets 終了 back to なし, and checks the rule is listed above 終了した定期
    /// again with 次回 3月25日（水）.
    private func resumeRule(app: XCUIApplication) {
        app.openRecurringRule(containing: ["毎月25日 85,000円 住居", "2026年2月まで"])
        expect(app.reads(app.recurringEndMonth, "2026年2月"), "終了が 2026年2月 と読めない")
        app.recurringEndMonth.tap()
        let none: XCUIElement = app.buttons["なし"]
        expect(none.waitForExistence(timeout: XCUIApplication.screenTimeout), "終了に なし の選択肢がない")
        none.tap()
        expect(app.reads(app.recurringEndMonth, "なし"), "終了を なし にしても なし と読めない")
        app.recurringSaveButton.tap()
        expect(app.disappears(app.recurringAmountField), "保存しても定期のシートが閉じない")

        let resumed: XCUIElement = app.recurringRuleRow(
            containing: ["毎月25日 85,000円 住居", "次回 3月25日（水）"]
        )
        expect(app.reveal(resumed), "再開した定期が 次回 3月25日（水） と並ばない")
        let order: [ScrolledRow] = app.recurringListInOrder()
        let headerIndex: Int? = order.firstIndex { row in
            row.identifier == "recurring-ended-header"
        }
        let ruleIndex: Int? = order.firstIndex { row in row.label.contains("次回 3月25日（水）") }
        expect(ruleIndex != nil, "再開した定期が一覧にない: \(order.map(\.label))")
        expect(
            headerIndex.map { header in (ruleIndex ?? header) < header } ?? true,
            "再開した定期が 終了した定期 の下に並ぶ: \(order.map(\.label))"
        )
    }

    /// Deletes the rule, checking that it asks first and changes nothing
    /// before the confirmation.
    private func deleteRule(app: XCUIApplication) {
        app.openRecurringRule(containing: ["毎月25日 85,000円 住居"])
        expect(app.recurringDeleteButton.exists, "定期のシートに 削除 がない")
        app.recurringDeleteButton.tap()
        expect(
            app.recurringDeleteConfirmButton.waitForExistence(
                timeout: XCUIApplication.screenTimeout
            ),
            "削除する前に確かめない"
        )
        app.recurringDeleteConfirmButton.tap()
        expect(app.disappears(app.recurringAmountField), "削除しても定期のシートが閉じない")
        let remaining: [ScrolledRow] = app.recurringListInOrder()
        expect(remaining.isEmpty, "削除した定期が一覧に残っている: \(remaining.map(\.label))")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

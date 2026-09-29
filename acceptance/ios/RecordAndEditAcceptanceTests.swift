import XCTest

/// AC-F-202 — A transaction is created and edited from the interface.
///
/// Given today 2026-02-15 and a February with no transactions. When the user
/// records an expense with amount `1200`, category 食費 and memo `ランチ`,
/// leaving the date unchanged, then an expense of 1,200 食費 on 2026-02-15
/// with memo `ランチ` is created, and the month's transactions list `1,200円`
/// with `支出` `1,200円`. When the user changes that transaction's amount to
/// `1500`, then it is updated and the list and `支出` show `1,500円`.
internal final class RecordAndEditAcceptanceTests: XCTestCase {
    /// Records 1,200円 食費 ランチ through the entry sheet, checking that it
    /// proposes 支出 and today, 2月15日, and leaving the date as proposed.
    private static func recordLunch(app: XCUIApplication) {
        app.openEntrySheet()
        expect(app.entryDirection.buttons["支出"].isSelected, "入力のシートが 支出 で始まらない")
        expect(app.reads(app.entryDate, "2月15日"), "入力のシートの日付が今日の 2月15日 でない")
        app.tapCategoryTile(named: "食費")
        app.entryMemoField.tap()
        app.entryMemoField.typeText("ランチ\n")
        app.replaceAmount(with: "1200")
        app.entrySaveButton.tap()
        expect(app.disappears(app.entryAmountField), "保存しても入力のシートが閉じない")
    }

    internal func test_AC_F_202_createsAndEditsTransaction() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-02-15")
        expect(app.transactionRowsInOrder().isEmpty, "記録する前から 2月 に記録がある")

        Self.recordLunch(app: app)

        let created: XCUIElement = app.transactionRow(
            on: "2026-02-15",
            containing: ["1,200円", "食費", "ランチ"]
        )
        expect(
            app.reveal(created),
            "2月15日 の 1,200円 食費 ランチ が一覧にない"
        )
        expect(app.transactionRowsInOrder().count == 1, "記録が 1 件でない")
        expect(
            app.shows(total: app.expenseTotal, name: "支出", amount: "1,200円"),
            "支出 が 1,200円 でない"
        )

        expect(app.reveal(created), "1,200円 の記録が見えない")
        created.tap()
        expect(
            app.entryAmountField.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "記録をタップしても修正のシートが開かない"
        )
        expect(app.buttons["entry-delete"].exists, "修正のシートに この記録を削除 がない")
        app.replaceAmount(with: "1500")
        app.entrySaveButton.tap()
        expect(app.disappears(app.entryAmountField), "保存しても修正のシートが閉じない")

        let updated: XCUIElement = app.transactionRow(
            on: "2026-02-15",
            containing: ["1,500円", "食費", "ランチ"]
        )
        expect(
            app.reveal(updated),
            "金額を変えた記録が 1,500円 食費 ランチ で一覧にない"
        )
        let rows: [ScrolledRow] = app.transactionRowsInOrder()
        expect(rows.count == 1, "修正で記録が 1 件でなくなった: \(rows.map(\.label))")
        expect(!rows.contains { row in row.label.contains("1,200円") }, "1,200円 の記録が残っている")
        expect(
            app.shows(total: app.expenseTotal, name: "支出", amount: "1,500円"),
            "支出 が 1,500円 にならない"
        )
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

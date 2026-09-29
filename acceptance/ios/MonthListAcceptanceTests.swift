import XCTest

/// AC-F-201 — The month's transactions and total are listed.
///
/// Given today 2026-02-15 and a ledger with an expense of 1,200 食費 memo
/// `ランチ` on 2026-02-10, an expense of 3,000 交通費 on 2026-02-14, an income
/// of 5,000 on 2026-02-01 and an expense of 800 食費 on 2026-01-31. When the
/// month's transactions are viewed, then they are the three February
/// transactions newest first — `3,000円` 交通費, `1,200円` 食費 `ランチ`,
/// `5,000円` — with `支出` `4,200円` and `収入` `5,000円`, and the January one
/// is not among them.
///
/// The ledger is built through the interface: each transaction is recorded
/// on its own date by relaunching with that date as today
/// (`-AcceptanceToday`) and keeping the date the entry sheet proposes.
internal final class MonthListAcceptanceTests: XCTestCase {
    /// Records the criterion's four transactions, each on its date, and
    /// returns the app relaunched on 2026-02-15.
    private static func launchedWithFourTransactions() -> XCUIApplication {
        let january: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-01-31")
        january.recordExpense(amount: "800", category: "食費", memo: nil)

        let salaryDay: XCUIApplication = january.relaunched(today: "2026-02-01")
        salaryDay.recordIncome(amount: "5000")

        let lunchDay: XCUIApplication = salaryDay.relaunched(today: "2026-02-10")
        lunchDay.recordExpense(amount: "1200", category: "食費", memo: "ランチ")

        let trainDay: XCUIApplication = lunchDay.relaunched(today: "2026-02-14")
        trainDay.recordExpense(amount: "3000", category: "交通費", memo: nil)

        return trainDay.relaunched(today: "2026-02-15")
    }

    /// Whether `row` is dated `isoDate` and its label holds every one of
    /// `texts`.
    private static func row(
        _ row: ScrolledRow,
        isOn isoDate: String,
        holding texts: [String]
    ) -> Bool {
        row.identifier.hasPrefix("transaction-row-\(isoDate)-")
            && texts.allSatisfy { text in row.label.contains(text) }
    }

    internal func test_AC_F_201_listsMonthsTransactionsAndTotals() {
        self.continueAfterFailure = false
        let app: XCUIApplication = Self.launchedWithFourTransactions()
        let newest: XCUIElement = app.transactionRow(on: "2026-02-14", containing: ["3,000円"])
        expect(app.reveal(newest), "2月14日 の 3,000円 が一覧にない")

        let rows: [ScrolledRow] = app.transactionRowsInOrder()
        expect(rows.count == 3, "2月 の記録が 3 件でない: \(rows.map(\.label))")
        expect(
            rows.count == 3
                && Self.row(rows[0], isOn: "2026-02-14", holding: ["3,000円", "交通費"])
                && Self.row(rows[1], isOn: "2026-02-10", holding: ["1,200円", "食費", "ランチ"])
                && Self.row(rows[2], isOn: "2026-02-01", holding: ["5,000円", "収入"]),
            "2月 の記録が 3,000円 交通費・1,200円 食費 ランチ・5,000円 収入 の新しい順でない: "
                + "\(rows.map(\.label))"
        )
        expect(
            !rows.contains { row in
                row.identifier.hasPrefix("transaction-row-2026-01-31-")
                    || row.label.contains("800円")
            },
            "1月31日 の 800円 が 2月 の一覧にある"
        )

        expect(
            app.shows(total: app.expenseTotal, name: "支出", amount: "4,200円"),
            "支出 が 4,200円 でない"
        )
        expect(
            app.shows(total: app.incomeTotal, name: "収入", amount: "5,000円"),
            "収入 が 5,000円 でない"
        )
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

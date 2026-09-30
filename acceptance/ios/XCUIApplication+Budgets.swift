import XCTest

/// The contract the app honours for budgets and closing a month (AC-F-401,
/// AC-F-402): the budget view and the sheets it opens.
///
/// The tab bar has the tab `予算`. The budget view shows the month in view:
/// the whole-month budget as `budget-whole`, then, in category order, one
/// row `budget-row-<category id>` for every category with a budget or with
/// spending in the month, then the ledger's savings as `budget-savings`
/// (labelled `貯金 11,500円`, at 0 too). A row's label reads as PRODUCT.md §5
/// writes a budget: `残り 11,500円` with `予算 30,000円`, `1,500円オーバー`
/// when overspent, and for a category without a budget only what was spent
/// (`3,000円`, no `残り`, no `予算`). Choosing a row opens its budget sheet,
/// and `budget-add` (+) opens the same sheet for another category, with
/// `category-tile-<category id>` tiles to choose it; the sheet has the amount
/// field `budget-amount` (a number pad) and the ✓ `budget-save`, which saves
/// the amount from the month in view on and closes the sheet. The whole-month
/// row opens the whole-month budget's sheet the same way, without tiles.
///
/// The offer to close a month is `budget-close-offer` at the top of the view,
/// labelled `2月を締めましょう`, and absent when there is nothing to close.
/// Choosing it asks first, in a sheet with the segmented control
/// `budget-close-policy` (`繰り越す` / `貯金にする`) and the button
/// `budget-close-confirm`, which closes the month and the sheet.
extension XCUIApplication {
    // MARK: - Budget view

    /// The whole-month budget's row (`budget-whole`).
    internal var budgetWholeRow: XCUIElement {
        self.descendants(matching: .any)["budget-whole"]
    }

    /// The ledger's savings (`budget-savings`), labelled `貯金 11,500円`.
    internal var budgetSavings: XCUIElement {
        self.descendants(matching: .any)["budget-savings"]
    }

    /// The offer to close a month (`budget-close-offer`), labelled
    /// `2月を締めましょう`.
    internal var budgetCloseOffer: XCUIElement {
        self.descendants(matching: .any)["budget-close-offer"]
    }

    /// The + that adds a budget for another category (`budget-add`).
    internal var budgetAddButton: XCUIElement {
        self.buttons["budget-add"]
    }

    // MARK: - Sheets

    /// The amount field of the budget sheet (`budget-amount`), a number
    /// pad.
    internal var budgetAmountField: XCUIElement {
        self.textFields["budget-amount"]
    }

    /// The ✓ of the budget sheet (`budget-save`).
    internal var budgetSaveButton: XCUIElement {
        self.buttons["budget-save"]
    }

    /// The carry-over policy control of the sheet that asks before closing
    /// (`budget-close-policy`): `繰り越す` or `貯金にする`.
    internal var budgetClosePolicy: XCUIElement {
        self.segmentedControls["budget-close-policy"]
    }

    /// The button of that sheet that closes the month
    /// (`budget-close-confirm`).
    internal var budgetCloseConfirmButton: XCUIElement {
        self.buttons["budget-close-confirm"]
    }

    // MARK: - Actions

    /// The row of the category named `name` in the budget view
    /// (`budget-row-<category id>`).
    internal func budgetRow(named name: String) -> XCUIElement {
        self.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH 'budget-row-' AND label CONTAINS %@",
                    name
                )
            )
            .firstMatch
    }

    /// Whether `element` reads every one of `texts` within the list timeout,
    /// scrolling it into view first.
    internal func budgetReads(_ element: XCUIElement, _ texts: [String]) -> Bool {
        guard self.revealNearTop(element) else {
            return false
        }
        var format: String = "exists == true"
        for _ in texts {
            format += " AND label CONTAINS %@"
        }
        let showing: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format, argumentArray: texts),
            object: element
        )
        return XCTWaiter().wait(for: [showing], timeout: Self.listTimeout) == .completed
    }

    /// Sets a budget of `amount` (typed as digits) from the month in view on:
    /// for the category named `category` through the +, or for the whole
    /// month when `category` is `nil`.
    internal func setBudget(amount: String, category: String?) {
        if let category {
            expect(
                self.budgetAddButton.waitForExistence(timeout: Self.screenTimeout),
                "予算を追加する + がない"
            )
            self.budgetAddButton.tap()
            self.tapCategoryTile(named: category)
        } else {
            expect(self.revealNearTop(self.budgetWholeRow), "予算に 月全体 の行がない")
            self.budgetWholeRow.tap()
        }
        expect(
            self.budgetAmountField.waitForExistence(timeout: Self.screenTimeout),
            "予算のシートが開かない"
        )
        self.replaceText(in: self.budgetAmountField, with: amount)
        self.budgetSaveButton.tap()
        expect(self.disappears(self.budgetAmountField), "保存しても予算のシートが閉じない")
    }

    /// Closes the month offered, choosing `貯金にする` and confirming.
    internal func closeOfferedMonthSavingLeftover() {
        self.budgetCloseOffer.tap()
        expect(
            self.budgetClosePolicy.waitForExistence(timeout: Self.screenTimeout),
            "締める前の確認が開かない"
        )
        self.budgetClosePolicy.buttons["貯金にする"].tap()
        self.budgetCloseConfirmButton.tap()
        expect(self.disappears(self.budgetCloseConfirmButton), "確認しても締める画面が閉じない")
    }
}

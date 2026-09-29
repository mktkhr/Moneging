import XCTest

/// The contract the app honours for the ledger's categories and monthly
/// recurring rules in 設定 (AC-F-203, AC-F-204).
///
/// 設定 has, for the ledger in view, a row `settings-categories` (分類) and a
/// row `settings-recurring` (毎月の定期), each reachable by swiping up.
extension XCUIApplication {
    /// Seconds a long press lasts to open a row's context menu.
    private static let longPressDuration: TimeInterval = 1.0

    // MARK: - 分類

    /// The + of 分類 that adds a category (`categories-add`).
    internal var categoriesAddButton: XCUIElement {
        self.buttons["categories-add"]
    }

    /// The name field of the editor adding or renaming a category
    /// (`category-name`); renaming prefills the current name.
    internal var categoryNameField: XCUIElement {
        self.textFields["category-name"]
    }

    /// The control that saves the name in that editor
    /// (`category-name-save`).
    ///
    /// It is hittable while the keyboard is up; saving closes the editor
    /// and returns to 分類.
    internal var categoryNameSaveButton: XCUIElement {
        self.buttons["category-name-save"]
    }

    // MARK: - 毎月の定期

    /// The + of 毎月の定期 that opens the rule sheet (`recurring-add`).
    internal var recurringAddButton: XCUIElement {
        self.buttons["recurring-add"]
    }

    /// The 支出 / 収入 segmented control of the rule sheet
    /// (`recurring-direction`).
    internal var recurringDirection: XCUIElement {
        self.segmentedControls["recurring-direction"]
    }

    /// The amount field of the rule sheet (`recurring-amount`), a number
    /// pad.
    internal var recurringAmountField: XCUIElement {
        self.textFields["recurring-amount"]
    }

    /// The day-of-month field of the rule sheet (`recurring-day`), 1 to 31,
    /// a number pad.
    internal var recurringDayField: XCUIElement {
        self.textFields["recurring-day"]
    }

    /// The control of the rule sheet choosing the month's last day
    /// (`recurring-month-end`, 月末) instead of a day.
    internal var recurringMonthEndButton: XCUIElement {
        self.buttons["recurring-month-end"]
    }

    /// The 土日祝のとき segmented control of the rule sheet
    /// (`recurring-adjustment`): そのまま (chosen until changed), 翌平日 or
    /// 前の平日.
    internal var recurringAdjustment: XCUIElement {
        self.segmentedControls["recurring-adjustment"]
    }

    /// The start month of the rule sheet (`recurring-start-month`); its
    /// label or value holds the month as `2026年2月`, the month of today
    /// until changed.
    internal var recurringStartMonth: XCUIElement {
        self.descendants(matching: .any)["recurring-start-month"]
    }

    /// The ✓ of the rule sheet (`recurring-save`), which creates the rule
    /// and closes the sheet.
    ///
    /// It is hittable while the keyboard is up.
    internal var recurringSaveButton: XCUIElement {
        self.buttons["recurring-save"]
    }

    /// The ledger's categories, one row each (`category-row-<category id>`).
    ///
    /// In the ledger's order; the label holds the name, and `アーカイブ済み`
    /// for an archived one. The list may need scrolling.
    private var categoryRows: XCUIElementQuery {
        self.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'category-row-'"))
    }

    /// Opens 分類 from 設定 (navigation bar titled `分類`).
    internal func openCategories() {
        self.openSettings()
        let row: XCUIElement = self.descendants(matching: .any)["settings-categories"]
        expect(self.reveal(row), "設定 に 分類 の行がない")
        row.tap()
        expect(
            self.navigationBars["分類"].waitForExistence(timeout: Self.screenTimeout),
            "分類 が開かない"
        )
    }

    /// The labels of the category rows, in list order, scrolling through
    /// the whole list.
    internal func categoryRowLabels() -> [String] {
        self.collectRows(self.categoryRows).map(\.label)
    }

    /// The rule rows of 毎月の定期, in list order, scrolling through the
    /// whole list.
    internal func recurringRuleRows() -> [ScrolledRow] {
        self.collectRows(
            self.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'recurring-rule-'"))
        )
    }

    /// The row of the category whose label holds `name`.
    internal func categoryRow(named name: String) -> XCUIElement {
        self.categoryRows.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    /// Opens the context menu of the category row holding `name` (a long
    /// press) and taps its item `identifier`: `category-rename`
    /// (名前を変える) or `category-archive` (アーカイブする…).
    internal func chooseCategoryAction(_ identifier: String, onCategoryNamed name: String) {
        let row: XCUIElement = self.categoryRow(named: name)
        expect(self.revealNearTop(row), "分類 \(name) の行がない")
        row.press(forDuration: Self.longPressDuration)
        let item: XCUIElement = self.buttons[identifier]
        expect(
            item.waitForExistence(timeout: Self.screenTimeout),
            "\(name) の行に \(identifier) がない"
        )
        item.tap()
    }

    /// Types `name` into the category name editor and saves it.
    internal func saveCategoryName(_ name: String) {
        expect(
            self.categoryNameField.waitForExistence(timeout: Self.screenTimeout),
            "分類の名前の入力欄が開かない"
        )
        self.replaceText(in: self.categoryNameField, with: name)
        self.categoryNameSaveButton.tap()
        expect(self.disappears(self.categoryNameField), "保存しても分類の名前の入力欄が閉じない")
    }

    /// Opens 毎月の定期 from 設定 (navigation bar titled `毎月の定期`).
    internal func openRecurringRules() {
        self.openSettings()
        let row: XCUIElement = self.descendants(matching: .any)["settings-recurring"]
        expect(self.reveal(row), "設定 に 毎月の定期 の行がない")
        row.tap()
        expect(
            self.navigationBars["毎月の定期"].waitForExistence(timeout: Self.screenTimeout),
            "毎月の定期 が開かない"
        )
    }

    /// Opens the rule sheet from 毎月の定期.
    internal func openRecurringRuleSheet() {
        expect(
            self.recurringAddButton.waitForExistence(timeout: Self.screenTimeout),
            "定期を追加する + がない"
        )
        self.recurringAddButton.tap()
        expect(
            self.recurringAmountField.waitForExistence(timeout: Self.screenTimeout),
            "定期を追加するシートが開かない"
        )
    }

    /// The rule row of 毎月の定期 (`recurring-rule-<rule id>`) whose label
    /// holds every one of `texts`: the rule as PRODUCT.md §5 writes it
    /// (`毎月25日 80,000円 住居`), the adjustment (`土日祝なら翌平日`) and
    /// the next date (`次回 3月25日（水）`).
    internal func recurringRuleRow(containing texts: [String]) -> XCUIElement {
        var format: String = "identifier BEGINSWITH 'recurring-rule-'"
        for _ in texts {
            format += " AND label CONTAINS %@"
        }
        return self.descendants(matching: .any)
            .matching(NSPredicate(format: format, argumentArray: texts))
            .firstMatch
    }

    /// Goes back from 毎月の定期 or 分類 to 設定, then to home.
    internal func leaveLedgerSettings() {
        self.navigationBars.buttons.element(boundBy: 0).tap()
        expect(
            self.navigationBars["設定"].waitForExistence(timeout: Self.screenTimeout),
            "設定 に戻れない"
        )
        self.leaveSettings()
    }
}

import XCTest

/// The contract the app honours for recording money (AC-F-201 to AC-F-204,
/// AC-E-201): the injected today, the home screen's month, the entry and
/// edit sheets, and the category tiles they offer.
///
/// Home lists the month in view: its `支出` / `収入` / `収支` totals, then its
/// transactions grouped by day, newest first. Each transaction is one row,
/// `transaction-row-<yyyy-MM-dd>-<transaction id>`, whose accessibility
/// label holds its amount (`1,200円`), its category (or `収入`), its memo,
/// and `定期` when a recurring rule recorded it. Tapping a row opens the edit
/// sheet.
extension XCUIApplication {
    /// Seconds a row or a total is given to show a change after a save.
    internal static let listTimeout: TimeInterval = 10

    /// The name of the launch argument injecting today's date.
    private static let todayArgumentName: String = "-AcceptanceToday"

    // MARK: - Home

    /// The month's expense total on home (`home-expense-total`); its label
    /// holds `支出` and the amount (`支出 4,200円`).
    internal var expenseTotal: XCUIElement {
        self.descendants(matching: .any)["home-expense-total"]
    }

    /// The month's income total on home (`home-income-total`); its label
    /// holds `収入` and the amount.
    internal var incomeTotal: XCUIElement {
        self.descendants(matching: .any)["home-income-total"]
    }

    // MARK: - Entry and edit sheets

    /// The 支出 / 収入 segmented control of the entry and edit sheets
    /// (`entry-direction`).
    internal var entryDirection: XCUIElement {
        self.segmentedControls["entry-direction"]
    }

    /// The amount field of the entry and edit sheets (`entry-amount`), a
    /// number pad.
    ///
    /// Typed digits appear in its value, with or without thousands
    /// separators.
    internal var entryAmountField: XCUIElement {
        self.textFields["entry-amount"]
    }

    /// The date of the entry and edit sheets (`entry-date`); its label or
    /// value holds the date as `2月15日`.
    internal var entryDate: XCUIElement {
        self.descendants(matching: .any)["entry-date"]
    }

    /// The memo field of the entry and edit sheets (`entry-memo`).
    internal var entryMemoField: XCUIElement {
        self.textFields["entry-memo"]
    }

    /// The ✓ of the sheet's toolbar (`entry-save`), which saves and closes
    /// the sheet.
    ///
    /// It is hittable while the keyboard is up.
    internal var entrySaveButton: XCUIElement {
        self.buttons["entry-save"]
    }

    /// The × of the sheet's toolbar (`entry-cancel`), which closes it,
    /// saving nothing.
    internal var entryCancelButton: XCUIElement {
        self.buttons["entry-cancel"]
    }

    /// The category tiles of the sheet shown (`category-tile-<category id>`,
    /// each labelled exactly with its category's name); none while 収入 is
    /// chosen.
    internal var categoryTiles: XCUIElementQuery {
        self.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'category-tile-'"))
    }

    /// Every transaction row of the month in view, in any order.
    private var transactionRows: XCUIElementQuery {
        self.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'transaction-row-'"))
    }

    /// Launch arguments that set the app's today to `isoDate`
    /// (`2026-02-15`), in Asia/Tokyo; debug builds only.
    ///
    /// The app's clock reads that date for as long as it runs: the date an
    /// entry defaults to, the month in view on launch, and the day recurring
    /// rules are recorded up to all follow it. A launch without the argument
    /// uses the device's clock.
    internal static func todayArguments(_ isoDate: String) -> [String] {
        [Self.todayArgumentName, isoDate]
    }

    /// Launches the app freshly installed, with today `isoDate` when one is
    /// given, and creates `家計` through the tour, leaving it in view on
    /// the home screen.
    internal static func launchedWithKakei(today isoDate: String?) -> XCUIApplication {
        let today: [String] = isoDate.map { date in Self.todayArguments(date) } ?? []
        let app: XCUIApplication = Self.launchedForAcceptance(
            arguments: Self.resetDataArguments + today
        )
        expect(
            app.tourStartButton.waitForExistence(timeout: Self.screenTimeout),
            "家計簿のない端末でツアーの最初の手順が表示されない"
        )
        app.tourStartButton.tap()
        app.finishTour()
        expect(app.showsLedgerInView(named: "家計"), "家計 が表示中の家計簿でない")
        return app
    }

    /// Terminates this app and launches it again, keeping its data, with
    /// today `isoDate`.
    internal func relaunched(today isoDate: String) -> XCUIApplication {
        self.terminate()
        let app: XCUIApplication = Self.launchedForAcceptance(
            arguments: Self.todayArguments(isoDate)
        )
        expect(app.showsLedgerInView(named: "家計"), "再起動後に 家計 が表示中の家計簿でない")
        return app
    }

    /// The transaction rows of the month in view, in list order, scrolling
    /// through the whole list.
    internal func transactionRowsInOrder() -> [ScrolledRow] {
        self.collectRows(self.transactionRows)
    }

    /// The first transaction row dated `isoDate` whose label holds every
    /// one of `texts`.
    internal func transactionRow(on isoDate: String, containing texts: [String]) -> XCUIElement {
        var format: String = "identifier BEGINSWITH %@"
        var arguments: [Any] = ["transaction-row-\(isoDate)-"]
        for text in texts {
            format += " AND label CONTAINS %@"
            arguments.append(text)
        }
        return self.descendants(matching: .any)
            .matching(NSPredicate(format: format, argumentArray: arguments))
            .firstMatch
    }

    /// Whether the total `total` shows `amount` (`4,200円`) within the list
    /// timeout, named by its label `name` (`支出`); scrolls it into view.
    internal func shows(total: XCUIElement, name: String, amount: String) -> Bool {
        guard self.revealNearTop(total) else {
            return false
        }
        let showing: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "exists == true AND label CONTAINS %@ AND label CONTAINS %@",
                name,
                amount
            ),
            object: total
        )
        return XCTWaiter().wait(for: [showing], timeout: Self.listTimeout) == .completed
    }

    /// Whether `element` is gone, or goes within the screen timeout.
    internal func disappears(_ element: XCUIElement) -> Bool {
        let gone: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        return XCTWaiter().wait(for: [gone], timeout: Self.screenTimeout) == .completed
    }

    /// Whether the label or the value of `element` holds `text`.
    internal func reads(_ element: XCUIElement, _ text: String) -> Bool {
        element.label.contains(text) || ((element.value as? String) ?? "").contains(text)
    }

    /// The tile of the category named `name` on the sheet shown.
    internal func categoryTile(named name: String) -> XCUIElement {
        self.categoryTiles.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    /// Scrolls the sheet shown to the tile of the category named `name` and
    /// taps it.
    internal func tapCategoryTile(named name: String) {
        let tile: XCUIElement = self.categoryTile(named: name)
        expect(self.revealInSheet(tile), "分類 \(name) のタイルがない")
        tile.tap()
    }

    /// Opens the entry sheet: the floating record button, then 手で入力する
    /// on the record sheet.
    internal func openEntrySheet() {
        let recordButton: XCUIElement = self.buttons["record-button"]
        expect(recordButton.waitForExistence(timeout: Self.screenTimeout), "記録するボタンがない")
        recordButton.tap()
        let manual: XCUIElement = self.descendants(matching: .any)["record-option-manual"]
        expect(
            manual.waitForExistence(timeout: Self.screenTimeout),
            "記録するシートに 手で入力する がない"
        )
        manual.tap()
        expect(
            self.entryAmountField.waitForExistence(timeout: Self.screenTimeout),
            "手で入力するシートが開かない"
        )
    }

    /// Records, through the entry sheet, an expense of `amount` (typed as
    /// digits) in the category named `category`, with `memo` when one is
    /// given, on the date the sheet proposes.
    internal func recordExpense(amount: String, category: String, memo: String?) {
        self.openEntrySheet()
        self.tapCategoryTile(named: category)
        self.fillAndSave(amount: amount, memo: memo)
    }

    /// Records, through the entry sheet, an income of `amount` (typed as
    /// digits) on the date the sheet proposes.
    internal func recordIncome(amount: String) {
        self.openEntrySheet()
        self.entryDirection.buttons["収入"].tap()
        expect(self.collectRowsInSheet(self.categoryTiles).isEmpty, "収入を選んでも分類が求められる")
        self.fillAndSave(amount: amount, memo: nil)
    }

    /// Replaces the text of the amount field with `digits`.
    internal func replaceAmount(with digits: String) {
        let field: XCUIElement = self.entryAmountField
        field.tap()
        let current: String = (field.value as? String) ?? ""
        let deletions: String = String(
            repeating: XCUIKeyboardKey.delete.rawValue,
            count: current.count
        )
        field.typeText(deletions + digits)
    }

    /// Types `memo` into the memo field (when given), then `amount` into the
    /// amount field, and saves the sheet.
    private func fillAndSave(amount: String, memo: String?) {
        if let memo {
            self.entryMemoField.tap()
            self.entryMemoField.typeText(memo + "\n")
        }
        self.replaceAmount(with: amount)
        self.entrySaveButton.tap()
        expect(self.disappears(self.entryAmountField), "保存しても入力のシートが閉じない")
    }
}

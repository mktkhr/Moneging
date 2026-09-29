import XCTest

/// The contract the app honours for the ledger in view, the ledger switcher,
/// adding a ledger and renaming one from 設定 (AC-F-102, AC-F-103,
/// AC-F-104, AC-E-101).
extension XCUIApplication {
    /// The longest name a ledger may have, in characters (PRODUCT.md §3).
    internal static let maxLedgerNameLength: Int = 20

    /// The most swipes the tests make to bring a row of 設定 into view.
    private static let maxSettingsSwipes: Int = 5

    /// The header title naming the ledger in view (`ledger-title-menu`); it
    /// opens the ledger switcher.
    internal var ledgerTitle: XCUIElement {
        self.buttons["ledger-title-menu"]
    }

    /// The switcher's control that opens the sheet adding a ledger
    /// (`ledger-menu-add`, labelled 家計簿を追加).
    internal var ledgerMenuAddButton: XCUIElement {
        self.buttons["ledger-menu-add"]
    }

    /// The name field of the sheet adding a ledger (`ledger-add-name`).
    internal var ledgerAddNameField: XCUIElement {
        self.textFields["ledger-add-name"]
    }

    /// The control that adds the ledger named in the sheet
    /// (`ledger-add-create`).
    internal var ledgerAddCreateButton: XCUIElement {
        self.buttons["ledger-add-create"]
    }

    /// The name field of the editor renaming a ledger (`ledger-rename-name`).
    internal var ledgerRenameNameField: XCUIElement {
        self.textFields["ledger-rename-name"]
    }

    /// The control that saves the name in the editor (`ledger-rename-save`).
    internal var ledgerRenameSaveButton: XCUIElement {
        self.buttons["ledger-rename-save"]
    }

    /// The row of 設定 that replays the tour (`settings-replay-tour`,
    /// 使い方をもう一度見る).
    internal var settingsReplayTourRow: XCUIElement {
        self.descendants(matching: .any)["settings-replay-tour"]
    }

    /// The header's account icon, which opens 設定 (`account-button`).
    internal var accountButton: XCUIElement {
        self.buttons["account-button"]
    }

    /// The switcher's rows, one per ledger (`ledger-menu-<ledger id>`), each
    /// labelled with exactly the ledger's name.
    private var ledgerMenuRows: XCUIElementQuery {
        self.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'ledger-menu-' AND identifier != 'ledger-menu-add'"
            )
        )
    }

    /// Whether the ledger named `name` is the ledger in view: the header's
    /// ledger title exists and names it, in its label or in a text inside it.
    internal func showsLedgerInView(named name: String) -> Bool {
        let title: XCUIElement = self.ledgerTitle
        guard title.waitForExistence(timeout: Self.screenTimeout) else {
            return false
        }
        return title.label.contains(name) || title.staticTexts[name].exists
    }

    /// Opens the ledger switcher from the header title.
    internal func openLedgerSwitcher() {
        expect(self.ledgerTitle.waitForExistence(timeout: Self.screenTimeout), "ヘッダーの家計簿名がない")
        self.ledgerTitle.tap()
        expect(
            self.ledgerMenuAddButton.waitForExistence(timeout: Self.screenTimeout),
            "家計簿の切り替えメニューが開かない"
        )
    }

    /// Opens the ledger switcher and returns, sorted, the names of the
    /// ledgers it offers to change to; the switcher is left open.
    internal func offeredLedgerNames() -> [String] {
        self.openLedgerSwitcher()
        return self.ledgerMenuRows.allElementsBoundByIndex.map(\.label).sorted()
    }

    /// Chooses the ledger named `name` in the switcher, opening it first if
    /// it is not open.
    internal func chooseLedger(named name: String) {
        if !self.ledgerMenuAddButton.exists {
            self.openLedgerSwitcher()
        }
        let row: XCUIElement = self.ledgerMenuRows.matching(
            NSPredicate(format: "label == %@", name)
        ).firstMatch
        expect(row.exists, "切り替えメニューに \(name) がない")
        row.tap()
    }

    /// Opens 設定 from the header's account icon.
    internal func openSettings() {
        expect(
            self.accountButton.waitForExistence(timeout: Self.screenTimeout),
            "ヘッダーにアカウントのアイコンがない"
        )
        self.accountButton.tap()
        expect(self.navigationBars["設定"].waitForExistence(timeout: Self.screenTimeout), "設定が開かない")
    }

    /// Goes back from 設定 to the screen with the ledger title.
    internal func leaveSettings() {
        self.navigationBars.buttons.element(boundBy: 0).tap()
        expect(self.ledgerTitle.waitForExistence(timeout: Self.screenTimeout), "設定から戻れない")
    }

    /// The row of 設定 naming the ledger `name`
    /// (`settings-ledger-name-<ledger id>`, labelled with exactly the name),
    /// swiped into view.
    internal func settingsLedgerRow(named name: String) -> XCUIElement {
        let row: XCUIElement = self.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH 'settings-ledger-name-' AND label == %@",
                    name
                )
            )
            .firstMatch
        self.swipeUp(toReveal: row)
        return row
    }

    /// Swipes up until `element` is hittable, at most a few times.
    internal func swipeUp(toReveal element: XCUIElement) {
        for _ in 0..<Self.maxSettingsSwipes {
            guard !(element.waitForExistence(timeout: 1) && element.isHittable) else {
                break
            }
            self.swipeUp()
        }
        expect(element.exists && element.isHittable, "\(element.description) が画面に出てこない")
    }

    /// Checks the name rule of the control `confirm` on the names typed
    /// into `field`.
    ///
    /// `confirm` must be disabled for an empty name, a name of spaces only
    /// and a name of 21 characters, and enabled for one of 20. Leaves
    /// `field` holding the 20 characters.
    internal func expectNameLimits(field: XCUIElement, confirm: XCUIElement) {
        self.replaceText(in: field, with: "")
        expect(!confirm.isEnabled, "空の名前で確定できる")

        self.replaceText(in: field, with: "   ")
        expect(!confirm.isEnabled, "空白だけの名前で確定できる")

        let tooLong: String = String(repeating: "あ", count: Self.maxLedgerNameLength + 1)
        self.replaceText(in: field, with: tooLong)
        expect(field.value as? String == tooLong, "21 文字の名前が入力欄に入らない")
        expect(!confirm.isEnabled, "21 文字の名前で確定できる")

        let longest: String = String(repeating: "あ", count: Self.maxLedgerNameLength)
        self.replaceText(in: field, with: longest)
        expect(confirm.isEnabled, "20 文字の名前で確定できない")
    }
}

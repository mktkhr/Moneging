import XCTest

/// The contract the app honours for a draft whose items do not add up
/// (AC-F-502), beside the draft's identifiers (`XCUIApplication+Scanning.swift`).
///
/// The fixture scanner also reads the receipt `corner-deli` (`-UITestScannerPages
/// corner-deli`): store `コーナーデリ`, date 2026-02-13, total 980, items 唐揚げ弁当 680
/// and 緑茶 150, both 食費.
///
/// **The warning.** While the draft's items do not add up to `draft-total`, the
/// element `draft-mismatch-warning` shows above the items; its label reads
/// `明細の合計 830円 が合計 980円 と 150円 合いません。次のどちらかで直せます。`
/// (the sentence naming the sum, the total and the difference, then
/// `次のどちらかで直せます。`, which is the sentence that the fixes below it
/// answer). When the sum is above the total the label reads the same way
/// with the amounts of the draft, and the fixes it offers are the second one
/// alone. The warning is absent while the items add up and while the draft has
/// no items.
///
/// **The two fixes**, buttons right below the warning: `draft-mismatch-add-difference`
/// (`差額 150円 を明細に足す`, present only while the sum is below the total;
/// it adds the item `差額` of the difference, which becomes the next
/// `draft-item-<n>` row) and `draft-mismatch-total-only`
/// (`明細を消して、合計 980円 だけで記録する`; it removes every item at once). After
/// the latter the draft has no `draft-item-<n>` row, shows `draft-whole-category`
/// (labelled `カテゴリ（全体）`, the whole expense's category, offered only while the
/// draft has no items) and shows `draft-undo-total-only` (`元に戻す`), which brings
/// the removed items back.
///
/// **The question.** Confirming (`draft-confirm`) while the items do not add up
/// is first asked in the middle of the screen, as an alert titled
/// `合計額が合いませんがよろしいですか？` whose message is the sentence naming the
/// three amounts followed by what is recorded, with the buttons
/// `draft-mismatch-accept` (`このまま記録する`) and `draft-mismatch-decline`
/// (`戻って直す`). Declining closes the alert and leaves the draft open and
/// unconfirmed. When the items add up, or the draft has no items, no alert is
/// asked.
///
/// **Marked records.** A record confirmed with its mismatch accepted is listed
/// with the mark `要確認` in the label of its transaction row; one confirmed
/// without a mismatch is not.
extension XCUIApplication {
    /// The warning of items that do not add up (`draft-mismatch-warning`).
    internal var mismatchWarning: XCUIElement {
        self.descendants(matching: .any)["draft-mismatch-warning"]
    }

    /// The fix that adds the difference as an item
    /// (`draft-mismatch-add-difference`).
    internal var addDifferenceButton: XCUIElement {
        self.buttons["draft-mismatch-add-difference"]
    }

    /// The fix that records the total alone (`draft-mismatch-total-only`).
    internal var totalOnlyButton: XCUIElement {
        self.buttons["draft-mismatch-total-only"]
    }

    /// The control that brings the items removed by recording the total alone
    /// back (`draft-undo-total-only`).
    internal var undoTotalOnlyButton: XCUIElement {
        self.buttons["draft-undo-total-only"]
    }

    /// The whole-expense category a draft without items offers
    /// (`draft-whole-category`).
    internal var wholeCategory: XCUIElement {
        self.descendants(matching: .any)["draft-whole-category"]
    }

    /// The question asked before recording items that do not add up.
    internal var mismatchAlert: XCUIElement {
        self.alerts.firstMatch
    }

    /// The question's button that records the mismatch
    /// (`draft-mismatch-accept`).
    internal var acceptMismatchButton: XCUIElement {
        self.buttons["draft-mismatch-accept"]
    }

    /// The question's button that returns to the draft
    /// (`draft-mismatch-decline`).
    internal var declineMismatchButton: XCUIElement {
        self.buttons["draft-mismatch-decline"]
    }

    /// Launches freshly installed with today `2026-02-15`, reading from photos
    /// enabled and the fixture scanner handing over `corner-deli` per scan,
    /// and creates `家計`.
    internal static func launchedWithMismatchedReceipt() -> XCUIApplication {
        Self.launchedScanning(
            arguments: Self.scannerArguments(pages: ["corner-deli"], picked: [])
                + ["-AcceptancePhotoReading", "YES"]
        )
    }

    /// Scans a receipt, waits for `確認待ち 1件` and opens the waiting draft.
    internal func scanAndOpenWaitingDraft() {
        self.startScan(option: "record-option-scan")
        expect(self.statusReads("確認待ち 1件"), "確認待ち 1件 が出ない: \(self.scanStatus.label)")
        self.openWaitingDraft()
    }

    /// Whether the warning reads `text` (a label holding it) within the screen
    /// timeout.
    internal func warningReads(_ text: String) -> Bool {
        let showing: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", text),
            object: self.mismatchWarning
        )
        return XCTWaiter().wait(for: [showing], timeout: Self.screenTimeout) == .completed
    }

    /// Whether the alert shown has a text (its title or its message) that
    /// reads `text` as a whole, within the screen timeout.
    internal func alertSays(_ text: String) -> Bool {
        self.mismatchAlert.staticTexts[text].waitForExistence(timeout: Self.screenTimeout)
    }

    /// Whether the alert shown has a message holding `text`.
    internal func alertMessageHolds(_ text: String) -> Bool {
        let holding: NSPredicate = NSPredicate(format: "label CONTAINS %@", text)
        return self.mismatchAlert.staticTexts.matching(holding).firstMatch
            .waitForExistence(timeout: Self.screenTimeout)
    }

    /// Whether the draft shown is not asked about anything: no alert shows
    /// after the confirm control has gone.
    internal func confirmedWithoutQuestion() -> Bool {
        self.disappears(self.draftConfirmButton) && !self.mismatchAlert.exists
    }

    /// The month's transaction rows of the receipt (`コーナーデリ` `980円`), in
    /// list order.
    internal func delicatessenRows() -> [ScrolledRow] {
        self.transactionRowsInOrder().filter { row in
            row.label.contains("コーナーデリ") && row.label.contains("980円")
        }
    }

    /// Replaces `draft-total` with `total` (digits) and waits for the draft to
    /// read it.
    internal func correctTotal(to total: String) {
        self.replaceText(in: self.draftField("draft-total"), with: total)
        expect(self.digits(of: self.draftField("draft-total")) == total, "合計 が \(total)円 にならない")
    }
}

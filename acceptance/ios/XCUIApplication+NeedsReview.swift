import XCTest

/// The contract the app honours for needs-review records (AC-F-503), beside
/// the draft and recording identifiers it builds on.
///
/// **Launch argument** (debug builds only): `-UITestSeedReviewRecords YES`.
/// Right after the onboarding creates the first ledger, the app records into
/// it two transactions marked needs-review (`isReviewNeeded` true), as if
/// drafts had been confirmed with their mismatch accepted:
/// - 980 yen on 2026-02-13 at `コーナーデリ`, in 食費, split into 唐揚げ弁当 680,
///   緑茶 150 and `差額` 150;
/// - 2,640 yen on 2026-01-20 at `ドラッグストア みどり`, in 日用品, split into
///   洗剤 2,000 and `差額` 640.
/// The fixture receipts hold no 2026-01-20 receipt, so these two cannot be
/// scanned; the confirm path itself is AC-F-502 and AC-B-508.
///
/// **Home.** While any record of the ledger in view is marked, the element
/// `review-status` shows below the ledger's name (under `scan-status` when
/// both show): its label holds `要確認 2件` and
/// `明細が合計と合わないまま記録したもの`. It is absent while no record is
/// marked. Choosing it opens the screen titled `要確認の記録`, which lists
/// every marked record of the ledger whatever its month, newest first, as
/// rows `review-list-row-<yyyy-MM-dd>-<transaction id>` labelled as home's
/// transaction rows are (amount, category, store, memo) and holding `要確認`.
/// The screen's first navigation-bar button goes back.
///
/// **Marks.** Wherever a marked record is listed (home's
/// `transaction-row-…`, the calendar's chosen day, the review list) its row
/// label holds `要確認`; an unmarked record's row never does.
///
/// **The record.** Choosing a row of the review list opens the edit sheet.
/// For a marked record it shows `review-explanation`, whose label is the
/// explanation (`要確認：読み取った明細が合計と合わなかったため「差額 150円」を
/// 足してあります。写真を見て直してください。`), and the button
/// `review-mark-reviewed` (`このままで確認済みにする`). Pressing the button
/// saves the record with `isReviewNeeded` false and closes the sheet, back in
/// the review list. An unmarked record's sheet shows neither.
extension XCUIApplication {
    /// The name of the launch argument seeding the two marked records.
    private static let seedArgumentName: String = "-UITestSeedReviewRecords"

    /// The count of marked records below the ledger's name
    /// (`review-status`).
    internal var reviewStatus: XCUIElement {
        self.descendants(matching: .any)["review-status"]
    }

    /// The explanation on the marked record's sheet (`review-explanation`).
    internal var reviewExplanation: XCUIElement {
        self.descendants(matching: .any)["review-explanation"]
    }

    /// The button that marks the record reviewed as it is
    /// (`review-mark-reviewed`).
    internal var markReviewedButton: XCUIElement {
        self.buttons["review-mark-reviewed"]
    }

    /// The review list screen's navigation bar (`要確認の記録`).
    internal var reviewListBar: XCUIElement {
        self.navigationBars["要確認の記録"]
    }

    /// Launches freshly installed with today `isoDate`, the two marked
    /// records seeded, and creates `家計` through the tour.
    internal static func launchedWithReviewRecords(today isoDate: String) -> XCUIApplication {
        let app: XCUIApplication = Self.launchedForAcceptance(
            arguments: Self.resetDataArguments + Self.todayArguments(isoDate)
                + [Self.seedArgumentName, "YES"]
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

    /// Whether the review status reads `count` (`要確認 2件`) within the
    /// screen timeout.
    internal func reviewStatusReads(_ count: String) -> Bool {
        let showing: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", count),
            object: self.reviewStatus
        )
        return XCTWaiter().wait(for: [showing], timeout: Self.screenTimeout) == .completed
    }

    /// Chooses the first tab of the tab bar, which is home.
    internal func openHomeTab() {
        let tab: XCUIElement = self.tabBars.buttons.element(boundBy: 0)
        expect(tab.waitForExistence(timeout: Self.screenTimeout), "下のタブバーがない")
        tab.tap()
        expect(self.ledgerTitle.waitForExistence(timeout: Self.screenTimeout), "ホームに戻れない")
    }

    /// Chooses the review status and waits for the review list screen.
    internal func openReviewList() {
        expect(self.reviewStatus.waitForExistence(timeout: Self.screenTimeout), "要確認の件数の表示がない")
        self.reviewStatus.tap()
        expect(
            self.reviewListBar.waitForExistence(timeout: Self.screenTimeout),
            "要確認の件数を選んでも 要確認の記録 が開かない"
        )
    }

    /// The rows of the review list, in list order.
    internal func reviewListRows() -> [ScrolledRow] {
        self.collectRows(
            self.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'review-list-row-'"))
        )
    }

    /// Goes back from the review list to home, if the list is in view.
    internal func leaveReviewList() {
        if self.reviewListBar.exists {
            self.navigationBars.buttons.element(boundBy: 0).tap()
        }
        expect(self.ledgerTitle.waitForExistence(timeout: Self.screenTimeout), "要確認の記録から戻れない")
    }

    /// Opens the review list's first row and waits for its explanation.
    internal func openFirstReviewRecord() {
        let row: XCUIElement = self.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'review-list-row-'"))
            .firstMatch
        expect(row.waitForExistence(timeout: Self.screenTimeout), "要確認の記録の一覧に行がない")
        row.tap()
        expect(
            self.reviewExplanation.waitForExistence(timeout: Self.screenTimeout),
            "印の付いた記録を開いても説明が出ない"
        )
    }

    /// Marks the record opened reviewed as it is and waits for its sheet to
    /// close.
    internal func markOpenedRecordReviewed() {
        expect(
            self.markReviewedButton.waitForExistence(timeout: Self.screenTimeout),
            "確認済みにするボタンがない"
        )
        self.markReviewedButton.tap()
        expect(self.disappears(self.reviewExplanation), "確認済みにしても説明が消えない")
    }
}

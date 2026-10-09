import XCTest

/// AC-F-502 — A draft warns of items that do not add up, offers to fix them,
/// and asks before recording.
///
/// Given today 2026-02-15 and the fixture scanner answering the draft of
/// `corner-deli.jpg` (store `コーナーデリ`, date 2026-02-13, total 980, items
/// 唐揚げ弁当 680 and 緑茶 150, both 食費). When a receipt is scanned and its
/// draft, waiting as `コーナーデリ` `980円`, is opened, then it shows the two
/// items and the warning `明細の合計 830円 が合計 980円 と 150円 合いません。`,
/// and offers both to add the difference as an item (`差額 150円 を明細に足す`)
/// and to record the total alone (`明細を消して、合計 980円 だけで記録する`). When
/// the difference is added, then a third item `差額` 150 in 食費 follows the
/// two and the warning goes; when the draft is confirmed, then it is saved
/// with the three items and confirmed without a question, `確認待ち`
/// disappears and the month's transactions list `980円` with `コーナーデリ`.
/// Given a new draft of it, when `合計` becomes 800, then the warning reads
/// `明細の合計 830円 が合計 800円 と 30円 合いません。` and adding the
/// difference is not offered, and confirming asks
/// `合計額が合いませんがよろしいですか？` saying
/// `明細の合計 830円 で記録し、要確認の印を付けます。`; declining leaves the
/// draft open and nothing confirmed. When `合計` is 980 again and the draft is
/// confirmed, then the question says
/// `差額 150円 を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。`;
/// accepting confirms the draft, and the month's transactions list `980円`
/// with `コーナーデリ`, marked `要確認`. Given a new draft of it, when the user
/// records the total alone, then the items go and the whole-expense `カテゴリ`
/// is offered; `元に戻す` brings the two items back, and when the total alone
/// is chosen again, confirming confirms without a question and the record is
/// not marked.
///
/// What the interface does not show (the draft saved with three items, the
/// `acceptMismatch` argument, the record's items and its `isReviewNeeded`) is
/// the shared logic's (AC-B-508); what it shows of them is asserted here.
internal final class MismatchedDraftAcceptanceTests: XCTestCase {
    /// The warning for the sum 830 against the total 980.
    private static let warningBelow: String = "明細の合計 830円 が合計 980円 と 150円 合いません。"

    /// The warning for the sum 830 against the total 800.
    private static let warningAbove: String = "明細の合計 830円 が合計 800円 と 30円 合いません。"

    /// The invitation that ends the warning and that the two fixes answer.
    private static let invitation: String = "次のどちらかで直せます。"

    /// The question's title.
    private static let questionTitle: String = "合計額が合いませんがよろしいですか？"

    /// Opens the waiting draft after checking its row reads `コーナーデリ`
    /// `980円`, then checks the two items, the warning and the two fixes.
    private static func checkDraftWarnsAndOffersFixes(_ app: XCUIApplication) {
        app.startScan(option: "record-option-scan")
        expect(app.statusReads("確認待ち 1件"), "確認待ち 1件 が出ない: \(app.scanStatus.label)")
        app.openDraftList()
        let row: XCUIElement = app.firstDraftRow
        expect(
            row.label.contains("コーナーデリ") && row.label.contains("980円"),
            "確認待ちの下書きが コーナーデリ 980円 でない: \(row.label)"
        )
        row.tap()
        expect(
            app.draftField("draft-store").waitForExistence(timeout: XCUIApplication.screenTimeout),
            "下書きが開かない"
        )
        checkTwoItems(app)
        expect(
            app.warningReads(Self.warningBelow),
            "警告が \(Self.warningBelow) でない: \(app.mismatchWarning.label)"
        )
        expect(app.mismatchWarning.label.contains(Self.invitation), "警告が \(Self.invitation) で終わらない")
        expect(app.addDifferenceButton.label == "差額 150円 を明細に足す", "差額を足す直し方がない")
        expect(
            app.totalOnlyButton.label == "明細を消して、合計 980円 だけで記録する",
            "合計だけで記録する直し方がない"
        )
    }

    /// Checks the draft's items are 唐揚げ弁当 680 and 緑茶 150, both 食費, and
    /// no third.
    private static func checkTwoItems(_ app: XCUIApplication) {
        let names: [String] = ["唐揚げ弁当", "緑茶"]
        let amounts: [String] = ["680円", "150円"]
        for index in 0..<names.count {
            let row: XCUIElement = app.draftItemRow(index)
            expect(
                row.waitForExistence(timeout: XCUIApplication.screenTimeout),
                "明細 \(index) の行がない"
            )
            expect(
                row.label.contains(names[index]),
                "明細 \(index) の品名が \(names[index]) でない: \(row.label)"
            )
            expect(
                row.label.contains(amounts[index]),
                "明細 \(index) の金額が \(amounts[index]) でない: \(row.label)"
            )
            expect(app.categoryName(of: row) == "食費", "明細 \(index) のカテゴリが 食費 でない")
        }
        expect(!app.draftItemRow(2).exists, "足していないのに 3 つ目の明細がある")
    }

    /// Adds the difference: the third item `差額` 150 in 食費, the warning
    /// gone; confirms without a question, and the month lists `980円` with
    /// `コーナーデリ`, not marked.
    private static func checkDifferenceAddedAndConfirmed(_ app: XCUIApplication) {
        app.addDifferenceButton.tap()
        let third: XCUIElement = app.draftItemRow(2)
        expect(third.waitForExistence(timeout: XCUIApplication.screenTimeout), "差額を足しても 3 つ目の明細がない")
        expect(
            third.label.contains("差額") && third.label.contains("150円"),
            "3 つ目が 差額 150円 でない: \(third.label)"
        )
        expect(app.categoryName(of: third) == "食費", "差額 のカテゴリが 食費 でない")
        expect(app.draftItemRow(0).label.contains("唐揚げ弁当"), "差額を足して 1 つ目の明細が変わった")
        expect(app.disappears(app.mismatchWarning), "差額を足しても警告が消えない")
        app.draftConfirmButton.tap()
        expect(app.confirmedWithoutQuestion(), "明細が合っているのに確認で問われる、または閉じない")
        expect(app.disappears(app.scanStatus), "確認しても 確認待ち が消えない")
        let rows: [ScrolledRow] = app.delicatessenRows()
        expect(rows.count == 1, "2月の 980円 コーナーデリ が 1 件でない: \(rows.count)")
        expect(!rows[0].label.contains("要確認"), "明細が合って記録したのに 要確認 の印がある")
    }

    /// With `合計` 800 the warning reads the 30円 and offers no difference;
    /// confirming asks, and declining leaves the draft open.
    private static func checkTotalBelowSumAsksAndDeclines(_ app: XCUIApplication) {
        app.scanAndOpenWaitingDraft()
        app.correctTotal(to: "800")
        expect(
            app.warningReads(Self.warningAbove),
            "警告が \(Self.warningAbove) でない: \(app.mismatchWarning.label)"
        )
        expect(!app.addDifferenceButton.exists, "合計が明細の合計より小さいのに差額を足す直し方がある")
        expect(app.totalOnlyButton.exists, "合計だけで記録する直し方がない")
        app.draftConfirmButton.tap()
        expect(
            app.mismatchAlert.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "確認で問われない"
        )
        expect(app.alertSays(Self.questionTitle), "問いが \(Self.questionTitle) でない")
        expect(
            app.alertMessageHolds("明細の合計 830円 と合計 800円 が 30円 違います。このまま記録すると、"),
            "問いが 3 つの金額を言わない"
        )
        expect(app.alertMessageHolds("明細の合計 830円 で記録し、要確認の印を付けます。"), "問いが 830円 で記録すると言わない")
        expect(app.acceptMismatchButton.label == "このまま記録する", "このまま記録する がない")
        expect(app.declineMismatchButton.label == "戻って直す", "戻って直す がない")
        app.declineMismatchButton.tap()
        expect(app.disappears(app.mismatchAlert), "戻って直す を押しても問いが閉じない")
        expect(app.draftConfirmButton.exists, "戻って直す を押したら下書きが閉じた")
        expect(app.digits(of: app.draftField("draft-total")) == "800", "戻って直す を押したら 合計 が変わった")
        expect(app.delicatessenRows().isEmpty, "戻って直す を押したのに記録ができた")
    }

    /// With `合計` 980 again the question names the 差額 150円, and accepting
    /// records it marked `要確認`.
    private static func checkAcceptedMismatchIsMarked(_ app: XCUIApplication) {
        app.correctTotal(to: "980")
        expect(app.warningReads(Self.warningBelow), "合計を戻しても警告が \(Self.warningBelow) にならない")
        app.draftConfirmButton.tap()
        expect(app.alertSays(Self.questionTitle), "問いが \(Self.questionTitle) でない")
        expect(
            app.alertMessageHolds("差額 150円 を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。"),
            "問いが 差額 150円 を足して要確認の印を付けると言わない"
        )
        app.acceptMismatchButton.tap()
        expect(app.disappears(app.draftConfirmButton), "このまま記録する を押しても下書きが閉じない")
        expect(app.disappears(app.scanStatus), "確認しても 確認待ち が消えない")
        let rows: [ScrolledRow] = app.delicatessenRows()
        expect(rows.count == 2, "2月の 980円 コーナーデリ が 2 件でない: \(rows.count)")
        let marked: Int = rows.filter { row in row.label.contains("要確認") }.count
        expect(marked == 1, "要確認 の印が付いた記録が 1 件でない: \(marked)")
    }

    /// Records the total alone: the items go and `カテゴリ` is offered;
    /// `元に戻す` brings them back; chosen again, confirming asks nothing and
    /// the record is not marked.
    private static func checkTotalAloneAndUndo(_ app: XCUIApplication) {
        app.scanAndOpenWaitingDraft()
        app.totalOnlyButton.tap()
        expect(app.disappears(app.draftItemRow(0)), "合計だけで記録しても明細が消えない")
        expect(
            app.wholeCategory.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "全体の カテゴリ が出ない"
        )
        expect(
            app.wholeCategory.label.contains("カテゴリ"),
            "全体の分類が カテゴリ でない: \(app.wholeCategory.label)"
        )
        expect(app.disappears(app.mismatchWarning), "明細を消しても警告が消えない")
        app.undoTotalOnlyButton.tap()
        expect(
            app.draftItemRow(0).waitForExistence(timeout: XCUIApplication.screenTimeout),
            "元に戻す で明細が戻らない"
        )
        expect(app.draftItemRow(0).label.contains("唐揚げ弁当"), "元に戻した 1 つ目が 唐揚げ弁当 でない")
        expect(app.draftItemRow(0).label.contains("680円"), "元に戻した 1 つ目が 680円 でない")
        expect(app.draftItemRow(1).label.contains("緑茶"), "元に戻した 2 つ目が 緑茶 でない")
        expect(app.draftItemRow(1).label.contains("150円"), "元に戻した 2 つ目が 150円 でない")
        expect(!app.draftItemRow(2).exists, "元に戻したら明細が 3 つになった")
        app.totalOnlyButton.tap()
        expect(app.disappears(app.draftItemRow(0)), "もう一度合計だけで記録しても明細が消えない")
        app.draftConfirmButton.tap()
        expect(app.confirmedWithoutQuestion(), "合計だけの下書きの確認で問われる、または閉じない")
        expect(app.disappears(app.scanStatus), "確認しても 確認待ち が消えない")
        let rows: [ScrolledRow] = app.delicatessenRows()
        expect(rows.count == 3, "2月の 980円 コーナーデリ が 3 件でない: \(rows.count)")
        let marked: Int = rows.filter { row in row.label.contains("要確認") }.count
        expect(marked == 1, "合計だけで記録したのに 要確認 の印が増えた: \(marked)")
    }

    internal func test_AC_F_502_draftWarnsOffersFixesAndAsksBeforeRecording() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedWithMismatchedReceipt()

        Self.checkDraftWarnsAndOffersFixes(app)
        Self.checkDifferenceAddedAndConfirmed(app)
        Self.checkTotalBelowSumAsksAndDeclines(app)
        Self.checkAcceptedMismatchIsMarked(app)
        Self.checkTotalAloneAndUndo(app)
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

import XCTest

/// AC-F-503 — Needs-review records are counted, marked wherever listed,
/// listed across months and marked reviewed.
///
/// Given today 2026-02-15, an expense of 1,150 食費 memo `カフェ` on
/// 2026-02-14, and two records marked needs-review: 980 on 2026-02-13 at
/// `コーナーデリ`, split into 唐揚げ弁当 680, 緑茶 150 and `差額` 150 in 食費,
/// and 2,640 on 2026-01-20 at `ドラッグストア みどり`, split into 洗剤 2,000
/// and `差額` 640 in 日用品. When the ledger is in view, then it shows
/// `要確認 2件` `明細が合計と合わないまま記録したもの`, and the month's
/// transactions show `980円` `コーナーデリ` with the `要確認` mark and
/// `1,150円` `カフェ` without. When the calendar's `2月13日 980円` is chosen,
/// then its `980円` `コーナーデリ` carries the mark too. When the
/// needs-review records are listed, then they are `980円` `コーナーデリ` and
/// `2,640円` `ドラッグストア みどり`, in that order, each with the mark. When
/// `コーナーデリ` is opened, then it explains
/// `要確認：読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。`,
/// and when the user marks it reviewed as it is, then `isReviewNeeded` false
/// is saved for it and the explanation goes; the count reads `要確認 1件` and
/// `コーナーデリ` in the month's transactions has no mark. When the
/// needs-review records are listed again, they are only
/// `ドラッグストア みどり`, whose explanation names `差額 640円`; when it too
/// is marked reviewed, then no `要確認` count or mark is shown at all.
///
/// The two marked records are seeded by `-UITestSeedReviewRecords YES`
/// (`XCUIApplication+NeedsReview.swift`); the café expense is recorded through
/// the interface on its own date. What the interface does not show
/// (`isReviewNeeded` itself) is the shared logic's (AC-B-509); the mark and
/// the count are what it shows of it.
internal final class ReviewNeededAcceptanceTests: XCTestCase {
    /// The mark every marked row carries.
    private static let mark: String = "要確認"

    /// The explanation of the 980 record, naming its `差額 150円`.
    private static let deliExplanation: String =
        "要確認：読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。"

    /// The explanation of the 2,640 record, naming its `差額 640円`.
    private static let drugstoreExplanation: String =
        "要確認：読み取った明細が合計と合わなかったため「差額 640円」を足してあります。写真を見て直してください。"

    /// Launches with today 2026-02-14, records the café expense on that
    /// date, and relaunches on 2026-02-15 keeping the data.
    private static func launchedWithRecords() -> XCUIApplication {
        let created: XCUIApplication = XCUIApplication.launchedWithReviewRecords(
            today: "2026-02-14"
        )
        created.recordExpense(amount: "1150", category: "食費", memo: "カフェ")
        return created.relaunched(today: "2026-02-15")
    }

    /// The month's row of `980円` `コーナーデリ` on 2026-02-13.
    private static func deliRow(_ app: XCUIApplication) -> XCUIElement {
        app.transactionRow(on: "2026-02-13", containing: ["980円", "コーナーデリ"])
    }

    /// The home view counts the two records and marks only theirs.
    private static func checkHomeCountsAndMarks(_ app: XCUIApplication) {
        expect(app.reviewStatusReads("要確認 2件"), "ホームに 要確認 2件 が出ない: \(app.reviewStatus.label)")
        expect(
            app.reviewStatus.label.contains("明細が合計と合わないまま記録したもの"),
            "件数に 明細が合計と合わないまま記録したもの がない: \(app.reviewStatus.label)"
        )
        expect(
            app.reviewStatus.frame.minY >= app.ledgerTitle.frame.maxY,
            "件数が家計簿の名前の下にない"
        )
        let deli: XCUIElement = Self.deliRow(app)
        expect(app.reveal(deli), "2月13日 の 980円 コーナーデリ が一覧にない")
        expect(deli.label.contains(Self.mark), "980円 コーナーデリ に 要確認 の印がない: \(deli.label)")
        let cafe: XCUIElement = app.transactionRow(on: "2026-02-14", containing: ["1,150円", "カフェ"])
        expect(app.reveal(cafe), "2月14日 の 1,150円 カフェ が一覧にない")
        expect(!cafe.label.contains(Self.mark), "1,150円 カフェ に 要確認 の印がある: \(cafe.label)")
    }

    /// The calendar's chosen day lists the marked record with its mark.
    private static func checkCalendarDayMarks(_ app: XCUIApplication) {
        app.openTab(named: "カレンダー")
        let day: XCUIElement = app.calendarDay("2026-02-13")
        expect(app.reveal(day), "カレンダーに 2月13日 がない")
        expect(day.label == "2月13日 980円", "13日 が 2月13日 980円 でない: \(day.label)")
        day.tap()
        let rows: [ScrolledRow] = app.chosenDayTransactionRows()
        let deli: [ScrolledRow] = rows.filter { row in
            row.label.contains("980円") && row.label.contains("コーナーデリ")
        }
        expect(deli.count == 1, "13日 に 980円 コーナーデリ が 1 件でない: \(rows.map(\.label))")
        expect(deli[0].label.contains(Self.mark), "選んだ日の 980円 コーナーデリ に 要確認 の印がない")
        app.openHomeTab()
    }

    /// The review list shows both records, newest first, each marked.
    private static func checkListNewestFirst(_ app: XCUIApplication) {
        app.openReviewList()
        let rows: [ScrolledRow] = app.reviewListRows()
        expect(rows.count == 2, "要確認の記録が 2 件でない: \(rows.map(\.label))")
        expect(
            rows[0].label.contains("980円") && rows[0].label.contains("コーナーデリ"),
            "1 件目が 980円 コーナーデリ でない: \(rows[0].label)"
        )
        expect(
            rows[1].label.contains("2,640円") && rows[1].label.contains("ドラッグストア みどり"),
            "2 件目が 2,640円 ドラッグストア みどり でない: \(rows[1].label)"
        )
        expect(rows.allSatisfy { row in row.label.contains(Self.mark) }, "一覧に 要確認 の印のない行がある")
        expect(rows[0].identifier.hasPrefix("review-list-row-2026-02-13-"), "1 件目が 2月13日 でない")
        expect(rows[1].identifier.hasPrefix("review-list-row-2026-01-20-"), "2 件目が 1月20日 でない")
    }

    /// Opens the record, checks its explanation, marks it reviewed and goes
    /// home.
    private static func review(_ app: XCUIApplication, explanation: String) {
        app.openFirstReviewRecord()
        expect(app.reviewExplanation.label == explanation, "説明が違う: \(app.reviewExplanation.label)")
        expect(app.markReviewedButton.label == "このままで確認済みにする", "このままで確認済みにする がない")
        app.markOpenedRecordReviewed()
        app.leaveReviewList()
    }

    /// One record is reviewed: the count is 1 and its row has no mark.
    private static func checkFirstReviewed(_ app: XCUIApplication) {
        Self.review(app, explanation: Self.deliExplanation)
        expect(app.reviewStatusReads("要確認 1件"), "確認済みにして 要確認 1件 にならない: \(app.reviewStatus.label)")
        let deli: XCUIElement = Self.deliRow(app)
        expect(app.reveal(deli), "確認済みにして 980円 コーナーデリ が一覧から消えた")
        expect(!deli.label.contains(Self.mark), "確認済みなのに 980円 コーナーデリ に印がある: \(deli.label)")
    }

    /// Only the drugstore record is listed; marking it reviewed leaves no
    /// count and no mark.
    private static func checkLastReviewed(_ app: XCUIApplication) {
        app.openReviewList()
        let rows: [ScrolledRow] = app.reviewListRows()
        expect(rows.count == 1, "要確認の記録が 1 件でない: \(rows.map(\.label))")
        expect(
            rows[0].label.contains("2,640円") && rows[0].label.contains("ドラッグストア みどり"),
            "残りが 2,640円 ドラッグストア みどり でない: \(rows[0].label)"
        )
        Self.review(app, explanation: Self.drugstoreExplanation)
        expect(app.disappears(app.reviewStatus), "すべて確認済みなのに 要確認 の件数が残る")
        let marked: [ScrolledRow] = app.transactionRowsInOrder().filter { row in
            row.label.contains(Self.mark)
        }
        expect(marked.isEmpty, "すべて確認済みなのに 要確認 の印が残る: \(marked.map(\.label))")
    }

    internal func test_AC_F_503_countsMarksListsAndReviewsNeedsReviewRecords() {
        self.continueAfterFailure = false
        let app: XCUIApplication = Self.launchedWithRecords()

        Self.checkHomeCountsAndMarks(app)
        Self.checkCalendarDayMarks(app)
        Self.checkListNewestFirst(app)
        Self.checkFirstReviewed(app)
        Self.checkLastReviewed(app)
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

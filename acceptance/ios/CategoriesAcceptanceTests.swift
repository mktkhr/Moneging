import XCTest

/// AC-F-203 — Categories are added, renamed and archived from the interface.
///
/// Given today 2026-02-15 and a ledger with the default categories. When the
/// ledger's categories are viewed, then the twelve defaults are listed in
/// order. When the user adds `ペット`, then it is created and listed last.
/// When the user renames 娯楽 to `趣味`, then it is listed as `趣味`. When the
/// user archives 趣味 and confirms, then it is listed as `アーカイブ済み` and
/// is not offered when recording.
internal final class CategoriesAcceptanceTests: XCTestCase {
    /// The default categories of a new ledger, in PRODUCT.md §3's order.
    private static let defaultCategoryNames: [String] = [
        "食費", "日用品", "住居", "水道光熱費", "交通費", "通信費",
        "医療", "教育", "娯楽", "交際費", "衣服", "その他",
    ]

    /// Whether `labels`, in order, name exactly `names`, each label holding
    /// its name and none marked `アーカイブ済み`.
    private static func labels(_ labels: [String], nameInOrder names: [String]) -> Bool {
        labels.count == names.count
            && zip(labels, names).allSatisfy { label, name in
                label.contains(name) && !label.contains("アーカイブ済み")
            }
    }

    internal func test_AC_F_203_addsRenamesAndArchivesCategories() {
        self.continueAfterFailure = false
        let app: XCUIApplication = XCUIApplication.launchedWithKakei(today: "2026-02-15")
        app.openCategories()
        let defaults: [String] = app.categoryRowLabels()
        expect(
            Self.labels(defaults, nameInOrder: Self.defaultCategoryNames),
            "既定の 12 の分類が順に並ばない: \(defaults)"
        )

        app.categoriesAddButton.tap()
        app.saveCategoryName("ペット")
        expect(
            app.reveal(app.categoryRow(named: "ペット")),
            "追加した ペット がない"
        )
        let withPet: [String] = app.categoryRowLabels()
        expect(
            Self.labels(withPet, nameInOrder: Self.defaultCategoryNames + ["ペット"]),
            "追加した ペット が既定の分類の後に並ばない: \(withPet)"
        )

        app.chooseCategoryAction("category-rename", onCategoryNamed: "娯楽")
        expect(
            app.categoryNameField.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "名前の入力欄が開かない"
        )
        expect(
            app.categoryNameField.value as? String == "娯楽",
            "名前を変える欄が 娯楽 で埋まっていない"
        )
        app.saveCategoryName("趣味")
        expect(
            app.reveal(app.categoryRow(named: "趣味")),
            "名前を変えた 趣味 がない"
        )
        expect(
            !app.categoryRowLabels().contains { label in label.contains("娯楽") },
            "名前を変えた 娯楽 が残っている"
        )

        self.archiveHobby(app: app)
        app.leaveLedgerSettings()

        app.openEntrySheet()
        let offered: [String] = app.collectRowsInSheet(app.categoryTiles).map(\.label)
        let expectedOffered: [String] =
            Self.defaultCategoryNames.filter { name in name != "娯楽" } + ["ペット"]
        expect(offered.sorted() == expectedOffered.sorted(), "記録で選べる分類が違う: \(offered)")
        expect(!offered.contains("趣味"), "アーカイブした 趣味 が記録で選べる")
        app.entryCancelButton.tap()
    }

    /// Archives 趣味, checking that it asks first and changes nothing before
    /// the confirmation.
    private func archiveHobby(app: XCUIApplication) {
        app.chooseCategoryAction("category-archive", onCategoryNamed: "趣味")
        let confirm: XCUIElement = app.buttons["category-archive-confirm"]
        expect(
            confirm.waitForExistence(timeout: XCUIApplication.screenTimeout),
            "アーカイブする前に確かめない"
        )
        expect(
            !app.categoryRow(named: "趣味").label.contains("アーカイブ済み"),
            "確かめる前にアーカイブされた"
        )
        confirm.tap()

        let archived: XCUIElement = app.categoryRow(named: "趣味")
        expect(app.reveal(archived), "アーカイブした 趣味 が一覧にない")
        let marked: XCTNSPredicateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS 'アーカイブ済み'"),
            object: archived
        )
        expect(
            XCTWaiter().wait(for: [marked], timeout: XCUIApplication.listTimeout) == .completed,
            "アーカイブした 趣味 が アーカイブ済み と示されない"
        )
        let archivedLabels: [String] = app.categoryRowLabels().filter { label in
            label.contains("アーカイブ済み")
        }
        expect(archivedLabels.count == 1, "アーカイブ済み が 趣味 だけでない: \(archivedLabels)")
    }

    deinit {
        // Nothing to release: every test launches and owns its own app.
    }
}

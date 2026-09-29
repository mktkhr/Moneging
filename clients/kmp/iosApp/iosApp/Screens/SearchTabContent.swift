import SharedLogic
import SwiftUI

/// 検索 tab root (`Search2.dc.html`, `SearchTyping2.dc.html`).
///
/// The search field at the bottom (the search tab's own, iOS 26), filter
/// chips (期間, 分類, 金額) at the top of the results, where the keyboard
/// never covers them, and the transactions of the ledger in view: the
/// recent ones before anything is typed or chosen, then those matching,
/// with their count and total. Every period is searched unless 期間 names
/// one; the text is found in memos, store names and item names. Tapping a
/// result opens its edit sheet.
///
/// Unlike every other tab's own content view (`HomeTabContent`,
/// `CalendarTabContent`, `ReportTabContent`, `BudgetTabContent`, each of
/// which owns its own `lifecycle` `@State`), this one receives `lifecycle`
/// from `RootView` instead. `Tab(value:role: .search)` was verified on the
/// simulator (`testTabRootsAreNotRecreatedAcrossTabSwitches`,
/// TabNavigationUITests) to reconstruct its content on every activation:
/// with `lifecycle` held here as `@State`, `search-tab-root`'s creation
/// count climbed to "5" after three round trips through every tab, where
/// every other tab's counter stayed "1". Hoisting it to `RootView` (created
/// once at the app root, so never recreated itself) keeps this tab's state
/// alive across switches the same way the others' local `@State` does.
internal struct SearchTabContent: View {
    private static let recentCount: Int = 20
    private static let monthsBack: Int32 = 24

    internal let path: Binding<NavigationPath>
    internal let lifecycle: TabRootLifecycle

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    @State private var query: String = ""
    @State private var month: String?
    @State private var categoryId: String?
    @State private var amountRange: SearchAmountRange = .any
    @State private var results: [SharedLogic.Transaction] = []

    private var isNarrowing: Bool {
        !self.query.trimmingCharacters(in: .whitespaces).isEmpty
            || self.month != nil || self.categoryId != nil || self.amountRange != .any
    }

    private var shown: [SharedLogic.Transaction] {
        self.isNarrowing ? self.results : Array(self.results.prefix(Self.recentCount))
    }

    // Everything the results depend on: a change searches again.
    private var searchKey: String {
        [
            self.query, self.month ?? "", self.categoryId ?? "", "\(self.amountRange)",
            "\(self.ledgerStore.state.hash)",
        ].joined(separator: "|")
    }

    private var summary: String {
        let expenses: [SharedLogic.Transaction] = self.results.filter { $0.direction == .expense }
        let expense: Int64 = expenses.reduce(0) { sum, transaction in sum + transaction.amount }
        return "\(self.results.count)件 ・ \(Formats.shared.yen(amount: expense))"
    }

    internal var body: some View {
        NavigationStack(path: self.path) {
            List {
                Section {
                    self.filterChips
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Theme.background)
                }
                Section {
                    if self.shown.isEmpty {
                        Text(self.isNarrowing ? "見つかりませんでした" : "記録はまだありません")
                            .foregroundStyle(Theme.mutedText)
                            .listRowBackground(Theme.surface)
                    }
                    ForEach(self.shown, id: \.id) { transaction in
                        self.row(transaction)
                    }
                } header: {
                    Text(self.isNarrowing ? self.summary : String(localized: "最近の記録"))
                        .accessibilityIdentifier("search-summary")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("検索")
            .searchable(text: self.$query, prompt: "メモ・店名・品名で探す")
            .task(id: self.searchKey) {
                self.results = await self.ledgerStore.search(self.draft())
            }
            .appNavigationDestinations()
        }
        .tabRootLifecycleHook(screenID: "search", creationCount: self.lifecycle.creationCount)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer {
                HStack(spacing: Theme.Spacing.small) {
                    self.periodChip
                    self.categoryChip
                    SearchFilterChip(
                        title: self.amountRange.title,
                        isActive: self.amountRange != .any,
                        identifier: "search-filter-amount",
                    ) {
                        ForEach(SearchAmountRange.menuOrder, id: \.self) { range in
                            Button(range == .any ? String(localized: "すべての金額") : range.title) {
                                self.amountRange = range
                            }
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.extraSmall)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var periodChip: some View {
        SearchFilterChip(
            title: self.month.map { IsoFormats.shared.month(iso: $0) }
                ?? String(localized: "すべての期間"),
            isActive: self.month != nil,
            identifier: "search-filter-period",
        ) {
            Button("すべての期間") {
                self.month = nil
            }
            ForEach(
                IsoFormats.shared.monthsAround(
                    center: self.store.todayMonthIso, before: Self.monthsBack, after: 0
                )
                .reversed(),
                id: \.self,
            ) { month in
                Button(IsoFormats.shared.month(iso: month)) {
                    self.month = month
                }
            }
        }
    }

    private var categoryChip: some View {
        SearchFilterChip(
            title: self.ledgerStore.category(id: self.categoryId)?.name ?? String(localized: "分類"),
            isActive: self.categoryId != nil,
            identifier: "search-filter-category",
        ) {
            Button("すべての分類") {
                self.categoryId = nil
            }
            ForEach(self.ledgerStore.state.categories, id: \.id) { category in
                Button(category.name) {
                    self.categoryId = category.id.description
                }
            }
        }
    }

    private func row(_ transaction: SharedLogic.Transaction) -> some View {
        let row: TransactionRow = self.ledgerStore.state.transactionRow(transaction: transaction)
        let dateText: String = IsoFormats.shared.date(iso: row.date, withWeekday: false)
        return Button {
            self.router.entrySheet = .edit(transaction)
        } label: {
            TransactionRowView(row: row, dateText: dateText)
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dateText)、\(row.accessibilityLabel)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("search-result-\(row.id)")
    }

    private func draft() -> SearchDraft {
        SearchDraft(
            text: self.query,
            month: self.month,
            categoryId: self.categoryId,
            minAmount: self.amountRange.minAmount.map { KotlinLong(value: $0) },
            maxAmount: self.amountRange.maxAmount.map { KotlinLong(value: $0) },
        )
    }
}

#Preview {
    SearchTabContent(
        path: .constant(NavigationPath()),
        lifecycle: TabRootLifecycle(screenID: "search"),
    )
}

import SharedLogic
import SwiftUI

/// ホーム tab root content (`Home2.dc.html`, `Home5.dc.html`): while any
/// scan is in flight or any draft waits, how many (opening レシートの読み取り);
/// the month in view's 支出 / 収入 / 収支, then its transactions grouped by
/// day, newest first.
///
/// Each transaction is a row `transaction-row-<yyyy-MM-dd>-<id>`; tapping
/// it opens its edit sheet, swiping it deletes it. While the month is read
/// a progress indicator shows, and a month with nothing recorded says so.
internal struct HomeTabContent: View {
    // Held here (the tab root's own content view), not at `RootView`: this
    // is where docs/handbook/architecture.md rule 3 puts screen state, and
    // `RootView` itself is created once at the app root, so this state
    // object is created exactly once for as long as `HomeTabContent` is
    // never recreated. See `testTabRootsAreNotRecreatedAcrossTabSwitches`
    // (TabNavigationUITests) for how that is verified on the simulator.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "home")

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    // Whether the records shown are the month in view's of the ledger in view.
    private var isShowingMonthInView: Bool {
        let state: LedgerUiState = self.ledgerStore.state
        return state.isLoaded && (state.ledgerId ?? "") == self.store.selectedLedgerId
    }

    internal var body: some View {
        List {
            if let status = self.scanStore.state.statusText {
                Section {
                    ScanStatusBand(text: status) {
                        self.router.push(.scans)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Theme.background)
                }
            }
            Section {
                MonthTotalsCard(totals: self.ledgerStore.state.totals)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Theme.surface)
            }
            if let message = self.ledgerStore.state.loadErrorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(Theme.mutedText)
                        .listRowBackground(Theme.surface)
                }
            }
            self.monthSections
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tabRootLifecycleHook(screenID: "home", creationCount: self.lifecycle.creationCount)
    }

    // The month's days, or why there are none to show.
    @ViewBuilder private var monthSections: some View {
        if !self.isShowingMonthInView {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Theme.background)
            }
        } else if self.ledgerStore.daySections.isEmpty {
            Section {
                self.emptyState
                    .listRowBackground(Theme.background)
            }
        } else {
            ForEach(self.ledgerStore.daySections, id: \.date) { section in
                Section {
                    ForEach(section.rows, id: \.id) { row in
                        self.row(row)
                    }
                } header: {
                    self.header(section)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.small) {
            Text("この月の記録はまだありません")
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text("右下の＋から記録できます")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.extraLarge)
    }

    private func header(_ section: DaySection) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(section.title)
                Spacer()
                self.dayTotal(section)
            }
            VStack(alignment: .leading) {
                Text(section.title)
                self.dayTotal(section)
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.mutedText)
    }

    @ViewBuilder
    private func dayTotal(_ section: DaySection) -> some View {
        if let total = section.totalText {
            Text(total)
                .monospacedDigit()
        }
    }

    private func row(_ row: TransactionRow) -> some View {
        Button {
            if let transaction = self.ledgerStore.transaction(id: row.id) {
                self.router.entrySheet = .edit(transaction)
            }
        } label: {
            TransactionRowView(row: row)
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    _ = await self.ledgerStore.delete(id: row.id)
                }
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("transaction-row-\(row.date)-\(row.id)")
    }
}

#Preview {
    HomeTabContent()
}

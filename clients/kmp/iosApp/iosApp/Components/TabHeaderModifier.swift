import SwiftUI

/// Applies the tab screens' shared header: the large title (the current
/// ledger name; tapping it opens the ledger-switch menu), a month chip,
/// and the お知らせ/アカウント toolbar buttons.
///
/// Matches `scratchpad/design/project/OptionB.dc.html`'s header. Applied by
/// `MainTabScreen`, so every main tab reuses the same header.
internal struct TabHeaderModifier: ViewModifier {
    private static let firstMonth: Int = 1
    private static let lastMonth: Int = 12
    private static let monthChipSpacing: CGFloat = 4

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    @ViewBuilder private var ledgerMenuContent: some View {
        ForEach(self.store.ledgers, id: \.id) { ledger in
            Button {
                self.store.selectLedger(id: ledger.id)
            } label: {
                if ledger.id == self.store.selectedLedgerId {
                    Label(ledger.name, systemImage: "checkmark")
                } else {
                    Text(ledger.name)
                }
            }
        }
        Divider()
        Button {
            self.router.push(.addLedger)
        } label: {
            Label("家計簿を追加", systemImage: "plus")
        }
    }

    private var monthChip: some View {
        Menu {
            ForEach(Self.firstMonth...Self.lastMonth, id: \.self) { month in
                Button("\(month)月") {
                    self.store.selectMonth(month)
                }
            }
        } label: {
            HStack(spacing: Self.monthChipSpacing) {
                Text("\(self.store.selectedMonth)月")
                Image(systemName: "chevron.down")
            }
        }
        .accessibilityLabel("表示する月（\(self.store.selectedMonth)月）")
    }

    internal func body(content: Content) -> some View {
        content
            .navigationTitle(self.store.selectedLedgerName)
            .navigationBarTitleDisplayMode(.large)
            .toolbarTitleMenu {
                self.ledgerMenuContent
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    self.monthChip
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.router.push(.notifications)
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("お知らせ（未読あり）")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.router.push(.settings)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("アカウント")
                }
            }
    }
}

extension View {
    /// Applies `TabHeaderModifier` to the current `NavigationStack` root.
    internal func tabHeader() -> some View {
        self.modifier(TabHeaderModifier())
    }
}

import SwiftUI

/// Applies the tab screens' shared header: the large title (the current
/// ledger name; tapping it opens the ledger-switch menu), a month chip,
/// and the お知らせ/アカウント toolbar buttons.
///
/// Matches `scratchpad/design/project/OptionB.dc.html`'s header. Applied by
/// `MainTabScreen`, so every main tab reuses the same header.
///
/// The ledger name uses a custom `Menu`-backed title row (`safeAreaInset`)
/// rather than SwiftUI's `toolbarTitleMenu`: the latter renders reliably,
/// but empirically its tap target does not open the menu in this project's
/// toolchain, which would leave the ledger switcher unusable.
internal struct TabHeaderModifier: ViewModifier {
    private static let firstMonth: Int = 1
    private static let lastMonth: Int = 12

    /// Whether this header reports its ledger title to the tour (ホーム's).
    internal let isTourHost: Bool

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    // The switcher: an icon-only + adding a ledger at the top, then the
    // ledgers, the one in view checked (its label stays its name).
    @ViewBuilder private var ledgerMenuContent: some View {
        ControlGroup {
            Button {
                self.router.isAddLedgerSheetPresented = true
            } label: {
                Label("家計簿を追加", systemImage: "plus")
            }
            .accessibilityIdentifier("ledger-menu-add")
        }
        .controlGroupStyle(.compactMenu)
        ForEach(self.store.ledgers, id: \.id) { ledger in
            let ledgerId: String = ledger.id.description
            Button {
                self.store.selectLedger(id: ledgerId)
            } label: {
                if ledgerId == self.store.selectedLedgerId {
                    Label(ledger.name, systemImage: "checkmark")
                } else {
                    Text(ledger.name)
                }
            }
            .accessibilityLabel(ledger.name)
            .accessibilityIdentifier("ledger-menu-\(ledgerId)")
        }
    }

    private var ledgerTitleRow: some View {
        HStack {
            Menu {
                self.ledgerMenuContent
            } label: {
                HStack(spacing: Theme.Spacing.small) {
                    Text(self.store.selectedLedgerName)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.text)
                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                }
            }
            .accessibilityIdentifier("ledger-title-menu")
            .tourTarget(.ledgerTitle, isReporting: self.isTourHost)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.top, Theme.Spacing.small)
        .padding(.bottom, Theme.Spacing.extraSmall)
        .background(Theme.background)
    }

    private var monthChip: some View {
        Menu {
            ForEach(Self.firstMonth...Self.lastMonth, id: \.self) { month in
                Button("\(month)月") {
                    self.store.selectMonth(month)
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.extraSmall) {
                Text("\(self.store.selectedMonth)月")
                Image(systemName: "chevron.down")
            }
        }
        .accessibilityLabel("表示する月（\(self.store.selectedMonth)月）")
        .accessibilityIdentifier("month-chip")
    }

    internal func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                self.ledgerTitleRow
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
                    .foregroundStyle(Theme.mutedText)
                    // No unread-notifications state exists yet (`AppUiState`
                    // has no notifications field), so the actual state is
                    // "no unread" - the label says only "お知らせ", not
                    // "お知らせ（未読あり）". Once unread state exists, this
                    // label should read it and add "（未読あり）" only when
                    // true.
                    .accessibilityLabel("お知らせ")
                    .accessibilityIdentifier("notifications-button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.router.push(.settings)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityLabel("アカウント")
                    .accessibilityIdentifier("account-button")
                }
            }
    }
}

extension View {
    /// Applies `TabHeaderModifier` to the current `NavigationStack` root.
    internal func tabHeader(isTourHost: Bool) -> some View {
        self.modifier(TabHeaderModifier(isTourHost: isTourHost))
    }
}

import SharedLogic
import SwiftUI

/// 設定: a grouped list, matching `Settings2.dc.html`: the ledger in
/// view's 分類 and 毎月の定期, placeholder rows, one row per ledger opening
/// the editor of its name, and 使い方をもう一度見る, which replays the tour
/// over ホーム.
internal struct SettingsScreen: View {
    private static let groups: [(title: String, items: [SettingsItem])] = [
        (title: "表示", items: [.appearance]),
        (title: "記録", items: [.receiptScanning]),
        (title: "端末", items: [.notificationsDevice, .backup]),
    ]

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    internal var body: some View {
        List {
            self.ledgerInViewSection
            ForEach(Self.groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.items, id: \.self) { item in
                        NavigationLink(value: Route.settingsDetail(item)) {
                            Text(item.label)
                        }
                        .accessibilityIdentifier("settings-\(item.identifier)")
                    }
                }
            }
            self.ledgerNamesSection
            Section("ヘルプ") {
                Button("使い方をもう一度見る") {
                    self.router.showHomeRoot()
                    self.store.replayTour()
                }
                .accessibilityIdentifier("settings-replay-tour")
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    // One row per ledger, opening the editor of its name.
    private var ledgerNamesSection: some View {
        Section {
            ForEach(self.store.ledgers, id: \.id) { ledger in
                NavigationLink(value: Route.renameLedger(ledger.id.description)) {
                    Text(ledger.name)
                }
                .accessibilityIdentifier("settings-ledger-name-\(ledger.id.description)")
            }
        } header: {
            Text("家計簿の名前")
        }
    }

    // 分類 and 毎月の定期 of the ledger in view.
    private var ledgerInViewSection: some View {
        Section {
            self.ledgerRow(
                title: "分類",
                count: self.ledgerStore.state.activeCategories.count,
                route: .categories,
                identifier: "settings-categories",
            )
            self.ledgerRow(
                title: "毎月の定期",
                count: self.ledgerStore.state.recurringRules.count,
                route: .recurringRules,
                identifier: "settings-recurring",
            )
        } header: {
            Text("家計簿「\(self.store.selectedLedgerName)」")
        }
    }

    private func ledgerRow(
        title: String,
        count: Int,
        route: Route,
        identifier: String,
    ) -> some View {
        NavigationLink(value: route) {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)件")
                    .foregroundStyle(Theme.mutedText)
            }
        }
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}

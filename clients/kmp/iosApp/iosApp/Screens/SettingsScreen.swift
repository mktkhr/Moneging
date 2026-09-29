import SharedLogic
import SwiftUI

/// 設定: a grouped list, matching
/// `scratchpad/design/project/Settings.dc.html`: placeholder rows, one row
/// per ledger opening the editor of its name, and 使い方をもう一度見る, which
/// replays the tour over ホーム.
internal struct SettingsScreen: View {
    private static let groups: [(title: String, items: [SettingsItem])] = [
        (title: "表示", items: [.appearance]),
        (title: "記録", items: [.categories, .receiptScanning]),
        (title: "端末", items: [.notificationsDevice, .backup]),
    ]

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    internal var body: some View {
        List {
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
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}

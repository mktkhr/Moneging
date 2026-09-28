import SwiftUI

/// 設定: a grouped list of placeholder rows, matching
/// `scratchpad/design/project/Settings.dc.html`.
internal struct SettingsScreen: View {
    private static let groups: [(title: String, items: [SettingsItem])] = [
        (title: "表示", items: [.appearance]),
        (title: "記録", items: [.categories, .receiptScanning]),
        (title: "端末", items: [.notificationsDevice, .backup]),
        (title: "家計簿", items: [.ledgerManagement]),
    ]

    internal var body: some View {
        List {
            ForEach(Self.groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.items, id: \.self) { item in
                        NavigationLink(value: Route.settingsDetail(item)) {
                            Text(item.label)
                        }
                    }
                }
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

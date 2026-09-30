import SharedLogic
import SwiftUI

/// 設定: a grouped list, matching `Settings2.dc.html`: the ledger in
/// view's 分類, 毎月の定期 and 予算の残りの扱い, placeholder rows, one row
/// per ledger opening the editor of its name, and 使い方をもう一度見る,
/// which replays the tour over ホーム.
internal struct SettingsScreen: View {
    private static let groups: [(title: String, items: [SettingsItem])] = [
        (title: "表示", items: [.appearance]),
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
            self.readingSection
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

    // Whether the device reads receipts from photos (PRODUCT.md §3, Photo reading).
    private var readingSection: some View {
        Section {
            let isOn: Binding<Bool> = Binding(
                get: { self.store.isPhotoReadingEnabled },
                set: { self.store.setPhotoReading($0) },
            )
            // The whole row turns it on or off, and reads as one switch.
            Button {
                isOn.wrappedValue.toggle()
            } label: {
                HStack(spacing: Theme.Spacing.medium) {
                    Text("写真からの読み取り")
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("写真からの読み取り", isOn: isOn)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation {
                Toggle("写真からの読み取り", isOn: isOn)
            }
            .accessibilityIdentifier("settings-photo-reading")
        } header: {
            Text("記録")
        } footer: {
            Text("レシートの写真から下書きを作ります。読み取りはこの端末の中だけで行います。")
        }
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
            self.carryOverRow
        } header: {
            Text("家計簿「\(self.store.selectedLedgerName)」")
        }
    }

    // What closing a month does with the leftover, kept for the ledger in view.
    private var carryOverRow: some View {
        Picker(
            "予算の残りの扱い",
            selection: Binding(
                get: { self.ledgerStore.state.carryOverPolicy },
                set: { policy in
                    Task {
                        _ = await self.ledgerStore.setCarryOverPolicy(policy)
                    }
                },
            ),
        ) {
            Text("繰り越す").tag(CarryOverPolicy.carry)
            Text("貯金にする").tag(CarryOverPolicy.save)
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("settings-carry-over")
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

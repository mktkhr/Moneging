import SwiftUI

/// 家計簿を追加, the sheet the ledger switcher's + opens.
///
/// Adding the ledger shows it and closes the sheet; 追加 is enabled only for
/// a name the rule accepts.
internal struct AddLedgerSheet: View {
    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var name: String = ""
    @State private var isSaving: Bool = false

    internal var body: some View {
        NavigationStack {
            Form {
                LedgerNameField(
                    text: self.$name,
                    identifier: "ledger-add-name",
                    isInitiallyFocused: true,
                )
            }
            .navigationTitle("家計簿を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        self.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加", action: self.add)
                        .disabled(!SharedStateStore.isValidLedgerName(self.name) || self.isSaving)
                        .accessibilityIdentifier("ledger-add-create")
                }
            }
        }
    }

    private func add() {
        self.isSaving = true
        Task {
            let isAdded: Bool = await self.store.addLedger(named: self.name)
            self.isSaving = false
            if isAdded {
                self.dismiss()
            }
        }
    }
}

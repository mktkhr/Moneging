import SharedLogic
import SwiftUI

/// The editor renaming one ledger, pushed from 設定.
///
/// Saving returns to 設定; 保存 is enabled only for a name the rule accepts.
/// The ledger in view stays as it is.
internal struct RenameLedgerScreen: View {
    /// `Ledger.id` of the ledger renamed, as text.
    internal let ledgerId: String

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(AppRouter.self)
    private var router: AppRouter

    @State private var name: String = ""
    @State private var isSaving: Bool = false

    internal var body: some View {
        Form {
            LedgerNameField(text: self.$name, identifier: "ledger-rename-name")
        }
        .navigationTitle("家計簿の名前")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: self.save)
                    .environment(
                        \.isEnabled, SharedStateStore.isValidLedgerName(self.name) && !self.isSaving
                    )
                    .accessibilityIdentifier("ledger-rename-save")
            }
        }
        .onAppear {
            self.name = self.store.ledgers.first { $0.id.description == self.ledgerId }?.name ?? ""
        }
    }

    private func save() {
        self.isSaving = true
        Task {
            let isRenamed: Bool = await self.store.renameLedger(id: self.ledgerId, to: self.name)
            self.isSaving = false
            if isRenamed {
                self.router.pop()
            }
        }
    }
}

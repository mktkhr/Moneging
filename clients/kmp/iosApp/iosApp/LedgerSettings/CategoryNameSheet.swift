import SwiftUI

/// The editor naming a category: adding one or renaming one.
///
/// 分類を追加, or 名前を変える prefilled with its name. 保存 is enabled for a name that
/// is not blank; saving closes the editor.
///
/// The field is `category-name`, the save button `category-name-save`.
internal struct CategoryNameSheet: View {
    internal let request: CategoryNameRequest

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var name: String = ""
    @State private var isSaving: Bool = false
    @State private var isPrepared: Bool = false

    private var isNameValid: Bool {
        !self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var title: String {
        switch self.request {
        case .add:
            String(localized: "分類を追加")

        case .rename:
            String(localized: "名前を変える")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .tint(Theme.text)
            .accessibilityIdentifier("category-name-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存", systemImage: "checkmark", role: .confirm, action: self.save)
                .disabled(!self.isNameValid || self.isSaving)
                .accessibilityIdentifier("category-name-save")
        }
    }

    internal var body: some View {
        NavigationStack {
            Form {
                Section {
                    NameTextField(
                        placeholder: String(localized: "分類の名前"),
                        text: self.$name,
                        identifier: "category-name",
                        onSubmit: {
                            // Saving is the toolbar button's; return only closes the keyboard.
                        },
                        isInitiallyFocused: true,
                    )
                    .frame(minHeight: Theme.minimumTapTarget)
                } header: {
                    Text("分類の名前")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                self.toolbar
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.medium, .large])
        .ledgerFailureAlert()
        .onAppear {
            guard !self.isPrepared else {
                return
            }
            self.isPrepared = true
            if case .rename(_, let currentName) = self.request {
                self.name = currentName
            }
        }
    }

    private func save() {
        self.isSaving = true
        Task {
            let isSaved: Bool
            switch self.request {
            case .add:
                isSaved = await self.ledgerStore.createCategory(named: self.name)

            case .rename(let categoryId, _):
                isSaved = await self.ledgerStore.renameCategory(id: categoryId, to: self.name)
            }
            self.isSaving = false
            if isSaved {
                self.dismiss()
            }
        }
    }
}

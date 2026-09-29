import SharedLogic
import SwiftUI

/// 分類 of the ledger in view (`Categories2.dc.html`): the categories in
/// use, in the ledger's order, then the archived ones, marked
/// アーカイブ済み. + adds one; a row's context menu (or a swipe) renames or
/// archives it, archiving only after a confirmation.
///
/// Rows are `category-row-<category id>`; + is `categories-add`; the menu's
/// items are `category-rename` and `category-archive`, the confirmation's
/// button `category-archive-confirm`.
internal struct CategoriesScreen: View {
    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @State private var nameRequest: CategoryNameRequest?
    @State private var archiving: SharedLogic.Category?

    private var active: [SharedLogic.Category] {
        self.ledgerStore.state.categories.filter { !$0.isArchived }
    }

    private var archived: [SharedLogic.Category] {
        self.ledgerStore.state.categories.filter(\.isArchived)
    }

    internal var body: some View {
        List {
            Section("使っている分類") {
                ForEach(self.active, id: \.id) { category in
                    self.activeRow(category)
                }
            }
            if !self.archived.isEmpty {
                Section {
                    ForEach(self.archived, id: \.id) { category in
                        self.archivedRow(category)
                    }
                } header: {
                    Text("アーカイブ済み")
                } footer: {
                    Text("記録には残りますが、新しい記録では選べません。")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("分類")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("分類を追加", systemImage: "plus") {
                    self.nameRequest = .add
                }
                .accessibilityIdentifier("categories-add")
            }
        }
        .sheet(item: self.$nameRequest) { request in
            CategoryNameSheet(request: request)
        }
        .sheet(
            isPresented: Binding(
                get: { self.archiving != nil },
                set: { isPresented in
                    if !isPresented {
                        self.archiving = nil
                    }
                },
            ),
        ) {
            if let category = self.archiving {
                ArchiveCategorySheet(category: category) {
                    self.archive(category)
                }
                .fittedSheet(maxHeight: nil)
            }
        }
        .ledgerFailureAlert()
    }

    private func label(_ category: SharedLogic.Category) -> some View {
        HStack(spacing: Theme.Spacing.medium) {
            CategoryIcon(defaultIndex: category.defaultIndex.map { Int(truncating: $0) })
            Text(category.name)
                .foregroundStyle(category.isArchived ? Theme.mutedText : Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if category.isArchived {
                Text("アーカイブ済み")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
            }
        }
    }

    private func activeRow(_ category: SharedLogic.Category) -> some View {
        self.label(category)
            .listRowBackground(Theme.surface)
            .contextMenu {
                self.actions(category)
            }
            .swipeActions(edge: .trailing) {
                self.actions(category)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(category.name)
            .accessibilityHint("長押しで名前を変える・アーカイブする")
            .accessibilityIdentifier("category-row-\(category.id.description)")
    }

    private func archivedRow(_ category: SharedLogic.Category) -> some View {
        self.label(category)
            .listRowBackground(Theme.surface)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(category.name)、アーカイブ済み")
            .accessibilityIdentifier("category-row-\(category.id.description)")
    }

    @ViewBuilder
    private func actions(_ category: SharedLogic.Category) -> some View {
        Button("名前を変える", systemImage: "pencil") {
            self.nameRequest = .rename(category.id.description, category.name)
        }
        .accessibilityIdentifier("category-rename")
        Button("アーカイブする…", systemImage: "archivebox", role: .destructive) {
            self.archiving = category
        }
        .accessibilityIdentifier("category-archive")
    }

    private func archive(_ category: SharedLogic.Category) {
        Task {
            _ = await self.ledgerStore.archiveCategory(id: category.id.description)
        }
    }
}

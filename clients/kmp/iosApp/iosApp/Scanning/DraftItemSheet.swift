import SharedLogic
import SwiftUI

/// 明細を直す (`DraftItemEdit5.dc.html`): one item of a draft.
///
/// 品名 over the whole width on as many lines as it needs
/// (`draft-item-name`), the amount large (`draft-item-amount`), and the
/// category as the record sheet's tiles. ✓ (`draft-item-save`) keeps the
/// changes, × (`draft-item-cancel`) closes it keeping nothing, and
/// この明細を消す (`draft-item-delete`) removes the item. Changing anything
/// makes the item certain (no longer 要確認).
internal struct DraftItemSheet: View {
    internal let editing: DraftItemEditing
    internal let categories: [SharedLogic.Category]
    /// Keeps the item as changed.
    internal let onSave: (DraftItemState) -> Void
    /// Removes the item; `nil` for a new one, which has nothing to remove.
    internal let onDelete: (() -> Void)?

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var categoryId: String?
    @State private var isPrepared: Bool = false

    private var isChanged: Bool {
        let item: DraftItemState = self.editing.item
        return self.name != item.name || self.amountText != item.amountText
            || self.categoryId != item.categoryId
    }

    internal var body: some View {
        NavigationStack {
            ScrollView {
                self.content
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.bottom, Theme.Spacing.extraLarge)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("明細を直す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                self.toolbar
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.large])
        .onAppear(perform: self.prepare)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .tint(Theme.text)
            .accessibilityIdentifier("draft-item-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存", systemImage: "checkmark", role: .confirm, action: self.save)
                .disabled((Int64(self.amountText) ?? 0) <= 0)
                .accessibilityIdentifier("draft-item-save")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                Text("品名")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
                TextField("品名", text: self.$name, axis: .vertical)
                    .lineLimit(1...)
                    .foregroundStyle(Theme.text)
                    .padding(Theme.Spacing.medium)
                    .background(
                        Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Scanning.cardRadius)
                    )
                    .accessibilityLabel("品名")
                    .accessibilityIdentifier("draft-item-name")
            }
            AmountHeader(
                text: self.$amountText,
                isIncome: false,
                splitTotal: nil,
                identifier: "draft-item-amount",
            )
            self.categorySection
            self.deleteButton
        }
    }

    // この明細を消す, for an item of the draft (a new one has nothing to remove).
    @ViewBuilder private var deleteButton: some View {
        if let onDelete = self.onDelete {
            Button(role: .destructive) {
                onDelete()
                self.dismiss()
            } label: {
                Text("この明細を消す")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.Scanning.review)
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("draft-item-delete")
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            HStack {
                Text("カテゴリ")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if self.categoryId != nil {
                    Button("選ばない（その他）") {
                        self.categoryId = nil
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("draft-item-category-clear")
                }
            }
            CategoryTileGrid(categories: self.categories, selection: self.$categoryId)
        }
    }

    private func prepare() {
        guard !self.isPrepared else {
            return
        }
        self.isPrepared = true
        self.name = self.editing.item.name
        self.amountText = self.editing.item.amountText
        self.categoryId = self.editing.item.categoryId
    }

    private func save() {
        var item: DraftItemState = self.editing.item
        if self.isChanged {
            item.name = self.name
            item.amountText = self.amountText
            item.categoryId = self.categoryId
            item.confidence = Theme.Scanning.certain
        }
        self.onSave(item)
        self.dismiss()
    }
}

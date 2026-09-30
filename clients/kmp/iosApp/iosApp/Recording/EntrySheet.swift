import SharedLogic
import SwiftUI

/// The entry sheet (`Entry2.dc.html`, `Income2.dc.html`, `Split2.dc.html`)
/// recording a transaction, and, given one, its edit sheet
/// (`Edit2.dc.html`), which can also delete it.
///
/// 支出 / 収入, the amount on the number pad, the category (an expense's;
/// an income has none), the date (today unless changed), the store name
/// and the memo; an expense may be split into line items, whose sum is its
/// amount. The toolbar's × closes it and ✓ saves it. A record linked to a
/// receipt's photo keeps it, and shows it (レシートの写真を見る).
internal struct EntrySheet: View {
    /// The transaction edited, or `nil` for a new record.
    internal let editing: SharedLogic.Transaction?
    /// The receipt photo a new record is linked to (one that could not be
    /// read), or `nil`.
    internal var newPhotoId: String?

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var isIncome: Bool = false
    @State private var amountText: String = ""
    @State private var categoryId: String?
    @State private var date: Date = Date()
    @State private var storeName: String = ""
    @State private var memo: String = ""
    @State private var items: [EntryItem] = []
    @State private var isSaving: Bool = false
    @State private var isDeleteConfirmationShown: Bool = false
    @State private var isPrepared: Bool = false

    // The photo the record is linked to: the edited one's, or the new one's.
    private var photoId: String? {
        self.editing?.photoId?.description ?? self.newPhotoId
    }

    private var isSplit: Bool {
        !self.items.isEmpty
    }

    private var itemsTotal: Int64 {
        self.items.reduce(0) { $0 + $1.amount }
    }

    private var canSave: Bool {
        if self.isIncome {
            return (Int64(self.amountText) ?? 0) > 0
        }
        if self.isSplit {
            return self.items.allSatisfy { $0.amount > 0 && $0.categoryId != nil }
        }
        return (Int64(self.amountText) ?? 0) > 0 && self.categoryId != nil
    }

    private var title: String {
        if self.editing != nil {
            return String(localized: "記録を修正")
        }
        return self.isIncome ? String(localized: "収入を記録") : String(localized: "支出を記録")
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
            .navigationTitle(self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                self.toolbar
            }
            .confirmationDialog(
                "この記録を削除しますか？",
                isPresented: self.$isDeleteConfirmationShown,
                titleVisibility: .visible,
            ) {
                Button("削除する", role: .destructive, action: self.delete)
                    .accessibilityIdentifier("entry-delete-confirm")
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.large])
        .ledgerFailureAlert()
        .onAppear(perform: self.prepare)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる", systemImage: "xmark", role: .close) {
                self.dismiss()
            }
            .tint(Theme.text)
            .accessibilityIdentifier("entry-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存", systemImage: "checkmark", role: .confirm, action: self.save)
                .disabled(!self.canSave || self.isSaving)
                .accessibilityIdentifier("entry-save")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
            Picker("支出か収入か", selection: self.$isIncome) {
                Text("支出").tag(false)
                Text("収入").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("entry-direction")
            AmountHeader(
                text: self.$amountText,
                isIncome: self.isIncome,
                splitTotal: self.isSplit && !self.isIncome ? self.itemsTotal : nil,
                identifier: "entry-amount",
            )
            self.categorySection
            EntryDetailsCard(
                date: self.$date,
                storeName: self.$storeName,
                memo: self.$memo,
                isIncome: self.isIncome,
                todayIso: self.store.todayIso,
            )
            self.extras
        }
    }

    // The receipt's photo (a record linked to one), splitting, deleting.
    @ViewBuilder private var extras: some View {
        if let photoId = self.photoId {
            ReceiptPhotoLink(
                photoId: photoId,
                width: Theme.Scanning.rowThumbnailWidth,
                height: Theme.Scanning.rowThumbnailHeight,
            )
        }
        if !self.isIncome, !self.isSplit {
            Button("明細に分ける", systemImage: "list.bullet", action: self.startSplit)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("entry-split")
        }
        if self.editing != nil {
            self.deleteButton
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            self.isDeleteConfirmationShown = true
        } label: {
            Text("この記録を削除")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Recording.destructive)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("entry-delete")
    }

    @ViewBuilder private var categorySection: some View {
        if self.isIncome {
            Text("収入には分類を付けません")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
        } else if self.isSplit {
            SplitItemsSection(
                items: self.$items,
                categories: self.ledgerStore.state.activeCategories,
                onStop: self.stopSplit,
            )
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("分類")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityAddTraits(.isHeader)
                CategoryTileGrid(
                    categories: self.ledgerStore.state.activeCategories,
                    selection: self.$categoryId,
                )
            }
        }
    }

    // Fills the form once: from the transaction edited, or today's date.
    private func prepare() {
        guard !self.isPrepared else {
            return
        }
        self.isPrepared = true
        guard let transaction = self.editing else {
            self.date = IsoDate.date(fromIso: self.store.todayIso)
            return
        }
        self.isIncome = transaction.direction == .income
        self.amountText = String(transaction.amount)
        self.categoryId = transaction.categoryId?.description
        self.date = IsoDate.date(fromIso: transaction.date.description)
        self.storeName = transaction.storeName ?? ""
        self.memo = transaction.memo ?? ""
        self.items = transaction.items.map { item in
            EntryItem(
                name: item.name ?? "",
                categoryId: item.categoryId.description,
                amountText: String(item.amount),
            )
        }
    }

    // Splits the expense: its amount and category become the first item.
    private func startSplit() {
        self.items = [
            EntryItem(categoryId: self.categoryId, amountText: self.amountText),
            EntryItem(),
        ]
    }

    // Back to one amount and category: the items' total, the first item's category.
    private func stopSplit() {
        self.amountText = self.itemsTotal > 0 ? String(self.itemsTotal) : ""
        self.categoryId = self.items.first?.categoryId
        self.items = []
    }

    private func draft() -> TransactionDraft {
        let isSplitExpense: Bool = self.isSplit && !self.isIncome
        let itemDrafts: [LineItemDraft] = self.items.map { item in
            LineItemDraft(name: item.name, categoryId: item.categoryId, amountText: item.amountText)
        }
        return TransactionDraft(
            date: IsoDate.iso(from: self.date),
            isIncome: self.isIncome,
            amountText: self.amountText,
            categoryId: self.isIncome || isSplitExpense ? nil : self.categoryId,
            storeName: self.isIncome ? "" : self.storeName,
            memo: self.memo,
            items: isSplitExpense ? itemDrafts : [],
            photoId: self.photoId,
        )
    }

    private func save() {
        self.isSaving = true
        let draft: TransactionDraft = self.draft()
        Task {
            let isSaved: Bool
            if let transaction = self.editing {
                isSaved = await self.ledgerStore.update(id: transaction.id.description, with: draft)
            } else {
                isSaved = await self.ledgerStore.record(draft)
            }
            self.isSaving = false
            if isSaved {
                self.dismiss()
            }
        }
    }

    private func delete() {
        guard let transaction = self.editing else {
            return
        }
        Task {
            if await self.ledgerStore.delete(id: transaction.id.description) {
                self.dismiss()
            }
        }
    }
}

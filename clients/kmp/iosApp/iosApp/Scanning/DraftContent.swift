import SharedLogic
import SwiftUI

/// The form of 下書きを確認 (`Draft5.dc.html`, `DraftItemsA5.dc.html`)
/// inside `DraftSheet`.
///
/// The receipt's photo, small, with how the draft was read below
/// レシートの写真を見る (`AI を使わずに読み取りました`); 店名, 日付 and 合計 (`DraftFieldsCard`); the
/// items to look at (`DraftItemRow`), each opening 明細を直す
/// (`DraftItemSheet`) and removable by swiping it left, with
/// ＋ 明細を足す, or, without items, one カテゴリ for the whole expense; and
/// discarding the draft, which asks first, from its own button.
///
/// While the items do not add up to 合計, a warning above them offers two
/// fixes (`DraftMismatchCard`, `Draft6.dc.html`): adding the item `差額`, or
/// recording the total alone, which removes the items at once and offers to
/// bring them back (`元に戻す`, `Draft6TotalOnly.dc.html`).
internal struct DraftContent: View {
    internal let form: Binding<DraftFormState>
    internal let photoId: String?
    /// How the draft was read, or `nil` for a draft from before the reading method.
    internal let readingMethodText: String?
    internal let categories: [SharedLogic.Category]
    internal let onDiscard: () -> Void

    @State private var editing: DraftItemEditing?
    @State private var isDiscardConfirmationShown: Bool = false
    /// The items removed by recording the total alone, to bring back; empty when none.
    @State private var removedItems: [DraftItemState] = []

    private var mismatch: DraftMismatch? {
        self.form.wrappedValue.form.mismatch()
    }

    // 明細 2件（合計 830円）, the sum in the warning colour while the items do not add up.
    private var itemsHeader: Text {
        let count: Int = self.form.wrappedValue.items.count
        let total: String = Formats.shared.yen(amount: self.form.wrappedValue.itemsTotal)
        let color: Color = self.mismatch == nil ? Theme.mutedText : Theme.Scanning.review
        let sum: Text = Text(total).foregroundStyle(color)
        return Text("明細 \(count)件（合計 \(sum)）")
    }

    internal var body: some View {
        List {
            Section {
                self.photoAndFields
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Theme.background)
            }
            if let mismatch = self.mismatch {
                Section {
                    DraftMismatchCard(
                        mismatch: mismatch,
                        onAddDifference: { self.addDifference(mismatch) },
                        onTotalOnly: self.recordTotalOnly,
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Theme.background)
                }
            }
            if self.form.wrappedValue.items.isEmpty {
                self.wholeCategory
            } else {
                self.items
            }
            Section {
                self.addItemButton
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Theme.background)
                self.discardButton
                    .listRowBackground(Theme.background)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .sheet(item: self.$editing) { editing in
            DraftItemSheet(
                editing: editing,
                categories: self.categories,
                onSave: { item in self.save(item, at: editing.index) },
                onDelete: editing.index.map { index in { self.remove(at: index) } },
            )
        }
    }

    private var photoAndFields: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            if let photoId = self.photoId {
                ReceiptPhotoLink(
                    photoId: photoId,
                    width: Theme.Scanning.draftThumbnailWidth,
                    height: Theme.Scanning.draftThumbnailHeight,
                    note: String(localized: "要確認 の欄は、読み取りに自信がない所です。"),
                    readingMethod: self.readingMethodText,
                )
            }
            DraftFieldsCard(form: self.form)
        }
    }

    // カテゴリ（全体）, and 元に戻す while the items removed by recording the total alone can come back.
    private var wholeCategory: some View {
        Section {
            DraftCategoryMenu(
                selection: self.form.categoryId,
                categories: self.categories,
                identifier: "draft-whole-category",
                accessibilityName: String(localized: "カテゴリ（全体）"),
            )
            .listRowBackground(Theme.surface)
            if !self.removedItems.isEmpty {
                self.undoNotice
                    .listRowBackground(Theme.Scanning.undoBackground)
            }
        } header: {
            Text("カテゴリ（全体）")
        }
    }

    private var undoNotice: some View {
        HStack {
            Text("明細を消しました。")
                .font(.subheadline)
                .foregroundStyle(Theme.text)
            Spacer()
            Button("元に戻す", action: self.undoTotalOnly)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.borderless)
                .frame(minHeight: Theme.minimumTapTarget)
                .accessibilityIdentifier("draft-undo-total-only")
        }
    }

    private var hasDifferenceItem: Bool {
        self.form.wrappedValue.items.contains { $0.name == "差額" }
    }

    private var numberedItems: [(offset: Int, element: DraftItemState)] {
        Array(self.form.wrappedValue.items.enumerated())
    }

    private var items: some View {
        Section {
            ForEach(self.numberedItems, id: \.element.id) { index, item in
                DraftItemRow(
                    item: item,
                    index: index,
                    categoryName: self.categoryName(of: item.categoryId),
                ) {
                    self.editing = DraftItemEditing(index: index, item: item)
                }
                .listRowBackground(Theme.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("削除", role: .destructive) {
                        self.remove(at: index)
                    }
                }
            }
        } header: {
            self.itemsHeader
        } footer: {
            if self.hasDifferenceItem {
                Text("押すと明細を直せます。左にすべらせると消せます。「差額」は、あとで写真を見て正しい品目に直せます。")
            } else {
                Text("押すと明細を直せます。左にすべらせると消せます。")
            }
        }
    }

    private var addItemButton: some View {
        Button {
            self.editing = DraftItemEditing(index: nil, item: DraftItemState.added())
        } label: {
            Label("明細を足す", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(
                            Theme.line,
                            style: StrokeStyle(
                                lineWidth: Theme.dashedBorderLineWidth,
                                dash: [Theme.dashedBorderDashLength, Theme.dashedBorderGapLength],
                            ),
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draft-item-add")
    }

    // Asks first, from the button itself.
    private var discardButton: some View {
        Button(role: .destructive) {
            self.isDiscardConfirmationShown = true
        } label: {
            Text("この下書きを捨てる")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.Scanning.review)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draft-discard")
        .confirmationDialog(
            "この下書きを捨てますか？",
            isPresented: self.$isDiscardConfirmationShown,
            titleVisibility: .visible,
        ) {
            Button("捨てる", role: .destructive, action: self.onDiscard)
                .accessibilityIdentifier("draft-discard-confirm")
        }
    }

    private func categoryName(of categoryId: String?) -> String? {
        self.categories.first { $0.id.description == categoryId }?.name
    }

    private func addDifference(_ mismatch: DraftMismatch) {
        guard let item = mismatch.differenceItem else {
            return
        }
        self.form.wrappedValue.items.append(DraftItemState.from(item))
    }

    // Removes every item at once, offering the whole expense's category: the
    // items' one category when they share it.
    private func recordTotalOnly() {
        let removed: [DraftItemState] = self.form.wrappedValue.items
        self.removedItems = removed
        let shared: Set<String?> = Set(removed.map(\.categoryId))
        if self.form.wrappedValue.categoryId == nil, shared.count == 1, let only = shared.first {
            self.form.wrappedValue.categoryId = only
        }
        self.form.wrappedValue.items = []
    }

    private func undoTotalOnly() {
        self.form.wrappedValue.items = self.removedItems
        self.removedItems = []
    }

    private func save(_ item: DraftItemState, at index: Int?) {
        if let index, self.form.wrappedValue.items.indices.contains(index) {
            self.form.wrappedValue.items[index] = item
        } else {
            self.form.wrappedValue.items.append(item)
            self.removedItems = []
        }
    }

    private func remove(at index: Int) {
        guard self.form.wrappedValue.items.indices.contains(index) else {
            return
        }
        self.form.wrappedValue.items.remove(at: index)
    }
}

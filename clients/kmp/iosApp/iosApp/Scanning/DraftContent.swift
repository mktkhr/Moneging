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
internal struct DraftContent: View {
    internal let form: Binding<DraftFormState>
    internal let photoId: String?
    /// How the draft was read, or `nil` for a draft from before the reading method.
    internal let readingMethodText: String?
    internal let categories: [SharedLogic.Category]
    internal let onDiscard: () -> Void

    @State private var editing: DraftItemEditing?
    @State private var isDiscardConfirmationShown: Bool = false

    private var itemsHeader: String {
        let count: Int = self.form.wrappedValue.items.count
        let total: String = Formats.shared.yen(amount: self.form.wrappedValue.itemsTotal)
        return String(localized: "明細 \(count)件（合計 \(total)）")
    }

    internal var body: some View {
        List {
            Section {
                self.photoAndFields
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Theme.background)
            }
            if self.form.wrappedValue.items.isEmpty {
                Section {
                    DraftCategoryMenu(
                        selection: self.form.categoryId,
                        categories: self.categories,
                        identifier: "draft-category",
                    )
                    .listRowBackground(Theme.surface)
                }
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
            Text(self.itemsHeader)
        } footer: {
            Text("押すと明細を直せます。左にすべらせると消せます。")
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

    private func save(_ item: DraftItemState, at index: Int?) {
        if let index, self.form.wrappedValue.items.indices.contains(index) {
            self.form.wrappedValue.items[index] = item
        } else {
            self.form.wrappedValue.items.append(item)
        }
    }

    private func remove(at index: Int) {
        guard self.form.wrappedValue.items.indices.contains(index) else {
            return
        }
        self.form.wrappedValue.items.remove(at: index)
    }
}

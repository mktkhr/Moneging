import SharedLogic
import SwiftUI

/// The line items of a split expense (`EditSplitA`, the draft's 案A).
///
/// Each item is a row to look at (its category, name and amount; a
/// discount item taken off, `−250円`); pressing it opens 明細を直す
/// (`DraftItemSheet`, identified `entry-item-…`) and swiping it left removes
/// it, while more than one is left. 明細を追加 opens the same sheet empty,
/// and 分けるのをやめる returns to one amount and category.
internal struct SplitItemsSection: View {
    internal let items: Binding<[EntryItem]>
    internal let categories: [SharedLogic.Category]
    internal let onStop: () -> Void
    /// Whether the record is marked needs-review: its `差額` item shows in
    /// the warning colour.
    internal var isDifferenceMarked: Bool = false

    @State private var editing: DraftItemEditing?
    @State private var openItemId: UUID?

    private var canRemove: Bool {
        self.items.wrappedValue.count > 1
    }

    private var numberedItems: [(offset: Int, element: EntryItem)] {
        Array(self.items.wrappedValue.enumerated())
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            self.header
            VStack(spacing: 0) {
                ForEach(self.numberedItems, id: \.element.id) { index, item in
                    self.row(item: item, index: index)
                    if item.id != self.items.wrappedValue.last?.id {
                        Divider()
                    }
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            Text("押すと明細を直せます。左にすべらせると消せます。")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
            self.addButton
        }
        .sheet(item: self.$editing) { editing in
            DraftItemSheet(
                editing: editing,
                categories: self.categories,
                onSave: { item in self.save(item, at: editing.index) },
                onDelete: self.canRemove
                    ? editing.index.map { index in { self.remove(at: index) } } : nil,
                identifierPrefix: "entry-item",
                requiresCategory: true,
            )
        }
    }

    private var header: some View {
        HStack {
            Text("明細（\(self.items.wrappedValue.count)件）")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
            Spacer()
            Button("分けるのをやめる", action: self.onStop)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("entry-split-stop")
        }
    }

    private var addButton: some View {
        Button {
            self.openItemId = nil
            self.editing = DraftItemEditing(index: nil, item: EntryItem().sheetItem)
        } label: {
            Label("明細を追加", systemImage: "plus")
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
        .accessibilityIdentifier("entry-split-add")
    }

    private func row(item: EntryItem, index: Int) -> some View {
        let category: SharedLogic.Category? = self.categories.first { choice in
            choice.id.description == item.categoryId
        }
        let isOpen: Binding<Bool> = Binding(
            get: { self.openItemId == item.id },
            set: { isOpen in self.openItemId = isOpen ? item.id : nil },
        )
        return EntryItemRow(
            item: item,
            index: index,
            category: category,
            isDifference: self.isDifferenceMarked
                && ReviewPresentationKt.isDifferenceItem(name: item.name),
        ) {
            if isOpen.wrappedValue {
                isOpen.wrappedValue = false
            } else {
                self.openItemId = nil
                self.editing = DraftItemEditing(index: index, item: item.sheetItem)
            }
        }
        .swipeToDelete(isEnabled: self.canRemove, isOpen: isOpen) {
            self.remove(at: index)
        }
    }

    // Keeps the sheet's item: over the one at `index`, or after the others.
    private func save(_ item: DraftItemState, at index: Int?) {
        guard let index else {
            var added: EntryItem = EntryItem()
            added.apply(item)
            self.items.wrappedValue.append(added)
            return
        }
        guard self.items.wrappedValue.indices.contains(index) else {
            return
        }
        self.items.wrappedValue[index].apply(item)
    }

    // Removes the item at `index`, while another is left.
    private func remove(at index: Int) {
        guard self.canRemove, self.items.wrappedValue.indices.contains(index) else {
            return
        }
        withAnimation {
            self.items.wrappedValue.remove(atOffsets: IndexSet(integer: index))
        }
        self.openItemId = nil
    }
}

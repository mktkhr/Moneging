import SharedLogic
import SwiftUI
import UIKit

/// The line items of a split expense (`Split2.dc.html`).
///
/// Each item has its category, item name and amount, may be marked 割引 (a
/// discount item, taken off: `−250円`), and can be removed;
/// 明細を追加 adds one, and 分けるのをやめる returns to one amount and
/// category.
internal struct SplitItemsSection: View {
    internal let items: Binding<[EntryItem]>
    internal let categories: [SharedLogic.Category]
    internal let onStop: () -> Void
    /// Whether the record is marked needs-review: its `差額` item shows in
    /// the warning colour.
    internal var isDifferenceMarked: Bool = false

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            self.header
            VStack(spacing: 0) {
                ForEach(self.items) { $item in
                    self.row(item: $item)
                    if item.id != self.items.wrappedValue.last?.id {
                        Divider()
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            self.addButton
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
            self.items.wrappedValue.append(EntryItem())
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

    private func row(item: Binding<EntryItem>) -> some View {
        let category: SharedLogic.Category? = self.categories.first { choice in
            choice.id.description == item.wrappedValue.categoryId
        }
        let name: String = item.wrappedValue.name
        let isDifference: Bool =
            self.isDifferenceMarked && ReviewPresentationKt.isDifferenceItem(name: name)
        let textColor: Color = isDifference ? Theme.Scanning.review : Theme.text
        return HStack(spacing: Theme.Spacing.medium) {
            self.categoryMenu(item: item, category: category)
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                TextField("品名", text: item.name)
                    .foregroundStyle(textColor)
                    .fontWeight(isDifference ? .bold : nil)
                Text(category?.name ?? String(localized: "分類を選ぶ"))
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
            }
            if item.wrappedValue.isDiscount {
                // A discount is taken off: its digits read below zero.
                Text("−")
                    .foregroundStyle(Theme.text)
                    .accessibilityHidden(true)
            }
            AmountTextField(
                placeholder: "0",
                text: item.amountText,
                identifier: "entry-item-amount",
                label: "明細の金額",
                font: UIFont.preferredFont(forTextStyle: .body),
                color: UIColor(textColor),
            )
            .fixedSize(horizontal: false, vertical: true)
            Text("円")
                .foregroundStyle(textColor)
            self.discountButton(item: item)
            if self.items.wrappedValue.count > 1 {
                self.removeButton(item: item)
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.small)
    }

    private func categoryMenu(
        item: Binding<EntryItem>,
        category: SharedLogic.Category?,
    ) -> some View {
        Menu {
            ForEach(self.categories, id: \.id) { choice in
                Button(choice.name) {
                    item.wrappedValue.categoryId = choice.id.description
                }
            }
        } label: {
            CategoryIcon(defaultIndex: category?.defaultIndex.map { Int(truncating: $0) })
        }
        .accessibilityLabel("分類 \(category?.name ?? String(localized: "未選択"))")
    }

    // 割引: turns the item into a discount taken off (`−250円`), or back.
    private func discountButton(item: Binding<EntryItem>) -> some View {
        let isDiscount: Bool = item.wrappedValue.isDiscount
        return Button {
            item.wrappedValue.isDiscount.toggle()
        } label: {
            Text("割引")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isDiscount ? Theme.onAccent : Theme.mutedText)
                .padding(.horizontal, Theme.Spacing.small)
                .padding(.vertical, Theme.Spacing.extraSmall)
                .background(isDiscount ? Theme.accent : Theme.background, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("割引")
        .accessibilityValue(isDiscount ? "1" : "0")
        .accessibilityAddTraits(isDiscount ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("entry-item-discount")
    }

    private func removeButton(item: Binding<EntryItem>) -> some View {
        Button {
            self.items.wrappedValue.removeAll { candidate in candidate.id == item.wrappedValue.id }
        } label: {
            Image(systemName: "minus.circle")
                .foregroundStyle(Theme.mutedText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("この明細を消す")
    }
}

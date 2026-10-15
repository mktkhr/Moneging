import SharedLogic
import SwiftUI

/// One item of a split expense, to look at (`EditSplitA`).
///
/// Its category's icon, its name with its category below it (a discount
/// item's as `食費・割引`), and its amount (a discount's below zero,
/// `−250円`) and a chevron on the right; the `差額` item of a record marked
/// needs-review shows in the warning colour. Pressing it opens 明細を直す.
/// It reads as `弁当 800円` with its category as its value, identified
/// `entry-split-item-<index>`.
internal struct EntryItemRow: View {
    internal let item: EntryItem
    /// Its position among the items, from 0.
    internal let index: Int
    internal let category: SharedLogic.Category?
    /// Whether it is the `差額` item of a record marked needs-review.
    internal let isDifference: Bool
    internal let onOpen: () -> Void

    private var amountText: String {
        Formats.shared.yen(amount: self.item.amount)
    }

    // Its category, before 割引 for a discount item (`食費・割引`).
    private var categoryText: String {
        let name: String = self.category?.name ?? String(localized: "分類を選ぶ")
        return self.item.isDiscount ? String(localized: "\(name)・割引") : name
    }

    private var textColor: Color {
        self.isDifference ? Theme.Scanning.review : Theme.text
    }

    internal var body: some View {
        Button(action: self.onOpen) {
            HStack(alignment: .center, spacing: Theme.Spacing.medium) {
                CategoryIcon(defaultIndex: self.category?.defaultIndex.map { Int(truncating: $0) })
                VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                    Text(self.item.name.isEmpty ? String(localized: "品名なし") : self.item.name)
                        .font(.body.weight(self.isDifference ? .bold : .medium))
                        .foregroundStyle(self.textColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(self.categoryText)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(self.amountText)
                    .font(.body.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(self.textColor)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.small)
            .frame(minHeight: Theme.minimumTapTarget)
            .background(Theme.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.item.name) \(self.amountText)")
        .accessibilityValue(self.category?.name ?? "")
        .accessibilityHint("押すと明細を直せます")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("entry-split-item-\(self.index)")
    }
}

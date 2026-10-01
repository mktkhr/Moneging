import SharedLogic
import SwiftUI

/// One item of a draft, to look at (`DraftItemsA5.dc.html`).
///
/// Its whole name wraps over as many lines as it needs, its category is
/// below it (未選択（その他） for none), and its amount and a chevron are on
/// the right (a discount item's below zero, `−250円`, its category after
/// 割引); 要確認 marks an item the scanner was not sure of. Pressing it
/// opens 明細を直す. It reads as `弁当 800円` with its category as its value,
/// identified `draft-item-<index>`.
internal struct DraftItemRow: View {
    internal let item: DraftItemState
    /// Its position among the items, from 0.
    internal let index: Int
    /// Its category's name, or `nil` for none.
    internal let categoryName: String?
    internal let onOpen: () -> Void

    private var amountText: String {
        Formats.shared.yen(amount: self.item.amount)
    }

    // Its category, after 割引 for a discount item (`割引・食費`).
    private var categoryText: String {
        let category: String = self.categoryName ?? String(localized: "未選択（その他）")
        return self.item.isDiscount ? String(localized: "割引・\(category)") : category
    }

    internal var body: some View {
        Button(action: self.onOpen) {
            HStack(alignment: .center, spacing: Theme.Spacing.medium) {
                VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                    Text(self.item.name.isEmpty ? String(localized: "品名なし") : self.item.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(self.categoryText)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if self.item.needsReview {
                    ReviewMark(field: "item-\(self.index)")
                }
                Text(self.amountText)
                    .font(.body.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.item.name) \(self.amountText)")
        .accessibilityValue(self.categoryName ?? "")
        .accessibilityHint("押すと明細を直せます")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("draft-item-\(self.index)")
    }
}

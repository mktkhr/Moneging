import SharedLogic
import SwiftUI

/// One transaction in a list (`Home2.dc.html`): its category's icon, its
/// category (or 収入) with a 定期 mark when a rule recorded it, its store
/// and memo, and its amount, an income's in the income colour with +.
///
/// At accessibility text sizes the amount moves under the text, so
/// nothing is squeezed.
internal struct TransactionRowView: View {
    internal let row: TransactionRow
    /// The date to show before the store and memo (search results), or `nil`.
    internal var dateText: String?

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize: DynamicTypeSize

    private var layout: AnyLayout {
        if self.dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.small))
        } else {
            AnyLayout(HStackLayout(spacing: Theme.Spacing.medium))
        }
    }

    private var detail: String? {
        let parts: [String] = [self.dateText, self.row.detail].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " ・ ")
    }

    internal var body: some View {
        self.layout {
            CategoryIcon(
                defaultIndex: self.row.iconIndex.map { Int(truncating: $0) },
                isIncome: self.row.isIncome,
            )
            VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
                HStack(spacing: Theme.Spacing.small) {
                    Text(self.row.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.text)
                    if self.row.isRecurring {
                        RecurringBadge()
                    }
                }
                if let detail = self.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(self.row.amountText)
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(self.row.isIncome ? Theme.income : Theme.text)
        }
        .contentShape(Rectangle())
    }
}

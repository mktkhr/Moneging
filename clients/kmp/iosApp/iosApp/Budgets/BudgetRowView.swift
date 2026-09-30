import SharedLogic
import SwiftUI

/// One category of the budget view (`budget-row-<category id>`).
///
/// Its icon and name, what is left (`残り 11,500円`), overspent (`1,500円オーバー`) or,
/// without a budget, spent (`3,000円`); then, with a budget, its bar and
/// `予算 30,000円・使った 18,500円`, else `予算なし`. Choosing it opens its
/// budget sheet.
internal struct BudgetRowView: View {
    internal let row: BudgetRow
    internal let onChoose: () -> Void

    internal var body: some View {
        Button(action: self.onChoose) {
            HStack(spacing: Theme.Spacing.medium) {
                CategoryIcon(defaultIndex: self.row.iconIndex.map { Int(truncating: $0) })
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    self.headline
                    if self.row.hasBudget {
                        BudgetBar(progress: self.row.progress, isOver: self.row.isOver)
                    }
                    self.details
                }
            }
            .padding(Theme.Spacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("budget-row-\(self.row.categoryId ?? "")")
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
            Text(self.row.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.text)
                .lineLimit(Theme.Budgets.nameLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(self.row.headline)
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(self.row.isOver ? Theme.Budgets.over : Theme.text)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var details: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.extraExtraSmall) {
            Text(self.row.detail)
            if let carried = self.row.carriedText {
                Text(carried)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.mutedText)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

import SharedLogic
import SwiftUI

/// The whole-month budget at the top of the budget view (`budget-whole`).
///
/// `2月の予算` with 変更 (設定 while unset), what is left in large
/// (`残り 28,500円`) or overspent (`1,500円オーバー`), its bar, and
/// `予算 50,000円` beside `使った 21,500円`. Unset, it shows 未設定 and what
/// the month spent. Choosing it opens the whole month's budget sheet.
internal struct BudgetWholeCard: View {
    internal let whole: WholeBudget
    internal let onChoose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle)
    private var amountSize: CGFloat = Theme.Budgets.wholeAmountFontSize

    internal var body: some View {
        Button(action: self.onChoose) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack(alignment: .firstTextBaseline) {
                    Text(self.whole.title)
                        .font(.footnote)
                        .foregroundStyle(Theme.mutedText)
                    Spacer()
                    Text(self.whole.actionText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
                self.amount
                if self.whole.hasBudget {
                    BudgetBar(progress: self.whole.progress, isOver: self.whole.isOver)
                }
                self.figures
            }
            .padding(Theme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(Theme.line)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.whole.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("budget-whole")
    }

    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
            if let caption = self.whole.caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
            }
            Text(self.whole.amountText)
                .font(.system(size: self.amountSize, weight: .bold).monospacedDigit())
                .foregroundStyle(self.whole.isOver ? Theme.Budgets.over : Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(Theme.Recording.totalMinimumScale)
        }
    }

    private var figures: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
            HStack {
                if let budget = self.whole.budgetText {
                    Text(budget)
                }
                Spacer()
                Text(self.whole.spentText)
            }
            if let carried = self.whole.carriedText {
                Text(carried)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.mutedText)
    }
}

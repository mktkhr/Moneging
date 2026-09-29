import SharedLogic
import SwiftUI

/// The month's 支出 / 収入 / 収支 at the top of ホーム (`Home2.dc.html`),
/// side by side, or one above the other at accessibility text sizes.
///
/// Each total is one accessibility element labelled with its name and
/// amount (`支出 4,200円`), identified `home-expense-total`,
/// `home-income-total` and `home-balance-total`.
internal struct MonthTotalsCard: View {
    internal let totals: MonthTotals

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize: DynamicTypeSize

    @ScaledMetric(relativeTo: .title3)
    private var amountSize: CGFloat = Theme.Recording.totalFontSize

    private var layout: AnyLayout {
        if self.dynamicTypeSize.isAccessibilitySize {
            AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.medium))
        } else {
            AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.small))
        }
    }

    internal var body: some View {
        self.layout {
            self.total(
                name: "支出",
                amount: Formats.shared.yen(amount: self.totals.expense),
                color: Theme.text,
                identifier: "home-expense-total",
            )
            self.total(
                name: "収入",
                amount: Formats.shared.yen(amount: self.totals.income),
                color: Theme.income,
                identifier: "home-income-total",
            )
            self.total(
                name: "収支",
                amount: Formats.shared.yen(amount: self.totals.balance),
                color: Theme.text,
                identifier: "home-balance-total",
            )
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func total(
        name: String,
        amount: String,
        color: Color,
        identifier: String,
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
            Text(name)
                .font(.caption)
                .foregroundStyle(Theme.mutedText)
            Text(amount)
                .font(.system(size: self.amountSize, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(Theme.Recording.totalMinimumScale)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(amount)")
        .accessibilityIdentifier(identifier)
    }
}

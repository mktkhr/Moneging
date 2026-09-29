import SharedLogic
import SwiftUI
import UIKit

/// The large amount at the top of the entry sheet: a number-pad field
/// (`entry-amount`) followed by 円, or, for a split record, the items'
/// total, which cannot be typed.
internal struct AmountHeader: View {
    internal let text: Binding<String>
    internal let isIncome: Bool
    /// The items' total when the record is split, else `nil`.
    internal let splitTotal: Int64?
    internal let identifier: String

    @ScaledMetric(relativeTo: .largeTitle)
    private var amountSize: CGFloat = Theme.Recording.amountFontSize

    private var color: Color {
        self.isIncome ? Theme.income : Theme.text
    }

    private var uiFont: UIFont {
        UIFont.systemFont(ofSize: self.amountSize, weight: .bold)
    }

    internal var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.extraExtraSmall) {
            Text("金額")
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.extraSmall) {
                self.amount
                Text("円")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(self.color)
                    .accessibilityHidden(true)
            }
            if self.splitTotal != nil {
                Text("明細の合計")
                    .font(.caption)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var amount: some View {
        if let total = self.splitTotal {
            Text(Formats.shared.yen(amount: total).dropLast())
                .font(.system(size: self.amountSize, weight: .bold).monospacedDigit())
                .foregroundStyle(self.color)
                .minimumScaleFactor(Theme.Recording.totalMinimumScale)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("金額 \(Formats.shared.yen(amount: total))")
        } else {
            AmountTextField(
                placeholder: "0",
                text: self.text,
                identifier: self.identifier,
                label: "金額",
                font: self.uiFont,
                color: UIColor(self.color),
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

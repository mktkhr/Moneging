import SharedLogic
import SwiftUI

/// The trend as twelve bars (`Report3.dc.html`), oldest first, the month in
/// view's in the accent colour, each with its month's number below.
///
/// Hidden from VoiceOver: the list below it says the same as text.
internal struct TrendBars: View {
    internal let trend: [TrendRow]

    @ScaledMetric(relativeTo: .body)
    private var maxHeight: CGFloat = Theme.Reports.barMaxHeight

    internal var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(self.trend, id: \.month) { month in
                VStack(spacing: Theme.Spacing.extraSmall) {
                    RoundedRectangle(cornerRadius: Theme.Reports.barRadius)
                        .fill(month.isMonthInView ? Theme.accent : Theme.Reports.bar)
                        .frame(
                            width: Theme.Reports.barWidth,
                            height: self.maxHeight * CGFloat(month.barFraction),
                        )
                    Text(month.monthNumber)
                        .font(.caption2)
                        .foregroundStyle(Theme.mutedText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minHeight: self.maxHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

import SharedLogic
import SwiftUI

/// The month's share as a ring (`Report3.dc.html`): one arc per category,
/// clockwise from the top, largest first, with the month's spending at its
/// centre.
///
/// Hidden from VoiceOver: the list beside it says the same as text.
internal struct ShareRing: View {
    internal let shares: [ShareRow]
    internal let expenseText: String

    @ScaledMetric(relativeTo: .body)
    private var diameter: CGFloat = Theme.Reports.ringDiameter

    internal var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Reports.ringTrack, lineWidth: Theme.Reports.ringLineWidth)
            ForEach(self.shares, id: \.categoryId) { share in
                Circle()
                    .trim(from: self.start(share), to: self.end(share))
                    .stroke(
                        Self.color(defaultIndex: share.iconIndex),
                        lineWidth: Theme.Reports.ringLineWidth,
                    )
                    .rotationEffect(.degrees(Theme.Reports.ringStartDegrees))
            }
            VStack(spacing: Theme.Spacing.extraExtraSmall) {
                Text("支出")
                    .font(.caption2)
                    .foregroundStyle(Theme.mutedText)
                Text(self.expenseText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Reports.dayAmountMinimumScale)
            }
            .padding(.horizontal, Theme.Reports.ringLineWidth)
        }
        .padding(Theme.Reports.ringInset)
        .frame(width: self.diameter, height: self.diameter)
        .accessibilityHidden(true)
    }

    /// The colour of the default category `defaultIndex`
    /// (`Category.defaultIndex`), or of an added one for `nil`.
    internal static func color(defaultIndex: KotlinInt?) -> Color {
        let colors: [Color] = Theme.Recording.categoryForegrounds
        guard let index = defaultIndex.map({ Int(truncating: $0) }), colors.indices.contains(index)
        else {
            return Theme.Recording.addedCategoryForeground
        }
        return colors[index]
    }

    // A lone category fills the ring; otherwise arcs keep a small gap.
    private func start(_ share: ShareRow) -> CGFloat {
        self.shares.count > 1 ? CGFloat(share.ringStart) + Theme.Reports.ringGap : 0
    }

    private func end(_ share: ShareRow) -> CGFloat {
        let end: CGFloat = CGFloat(share.ringEnd)
        return self.shares.count > 1 ? max(self.start(share), end - Theme.Reports.ringGap) : end
    }
}

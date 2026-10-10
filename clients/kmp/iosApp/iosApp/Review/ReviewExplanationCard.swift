import SharedLogic
import SwiftUI

/// Why a record is marked needs-review, at the top of its edit sheet.
///
/// `要確認：` in the warning colour, then the reason naming its `差額`
/// (`review-explanation`, `RecordReview7.dc.html`). Nothing for a record
/// that is not marked.
internal struct ReviewExplanationCard: View {
    /// The record edited, or `nil` for a new one.
    internal let transaction: SharedLogic.Transaction?

    @Environment(LedgerStore.self)
    private var ledgerStore: LedgerStore

    internal var body: some View {
        if let explanation = self.transaction.flatMap({ transaction in
            self.ledgerStore.reviewExplanation(id: transaction.id.description)
        }) {
            Self.card(explanation)
        }
    }

    private static func text(_ explanation: ReviewExplanation) -> AttributedString {
        var prefix: AttributedString = AttributedString(explanation.prefix)
        prefix.foregroundColor = Theme.Scanning.review
        prefix.font = .subheadline.weight(.bold)
        return prefix + AttributedString(explanation.body)
    }

    private static func card(_ explanation: ReviewExplanation) -> some View {
        Text(Self.text(explanation))
            .font(.subheadline)
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.large)
            .background(
                Theme.Scanning.review.opacity(Theme.Scanning.mismatchTintOpacity),
                in: RoundedRectangle(cornerRadius: Theme.Scanning.mismatchRadius),
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Scanning.mismatchRadius)
                    .strokeBorder(
                        Theme.Scanning.review.opacity(Theme.Scanning.mismatchBorderOpacity),
                        lineWidth: Theme.Scanning.mismatchBorderWidth,
                    )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(explanation.text)
            .accessibilityIdentifier("review-explanation")
    }
}

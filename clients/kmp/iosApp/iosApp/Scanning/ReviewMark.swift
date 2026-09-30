import SwiftUI

/// The 要確認 mark beside a draft's field the scanner was not sure of
/// (confidence below 0.6), `draft-review-<field>`.
internal struct ReviewMark: View {
    /// The field it marks: `store`, `date`, `total` or `item-<n>`.
    internal let field: String

    internal var body: some View {
        Text("要確認")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.Scanning.review)
            .padding(.horizontal, Theme.Spacing.small)
            .padding(.vertical, Theme.Spacing.extraExtraSmall)
            .background(
                Theme.Scanning.review.opacity(Theme.Scanning.reviewTintOpacity),
                in: RoundedRectangle(cornerRadius: Theme.Scanning.reviewRadius),
            )
            .accessibilityIdentifier("draft-review-\(self.field)")
    }
}

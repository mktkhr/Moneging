import SwiftUI

/// The 要確認 mark of a transaction confirmed from a draft whose items did not
/// add up, in the warning colour.
internal struct NeedsReviewBadge: View {
    internal var body: some View {
        Text("要確認")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.Scanning.review)
            .padding(.horizontal, Theme.Spacing.small)
            .padding(.vertical, Theme.Spacing.extraExtraSmall)
            .background(
                Theme.Scanning.review.opacity(Theme.Scanning.reviewTintOpacity),
                in: RoundedRectangle(cornerRadius: Theme.Recording.badgeRadius),
            )
    }
}

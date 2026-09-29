import SwiftUI

/// The 定期 mark of a transaction a recurring rule recorded.
internal struct RecurringBadge: View {
    internal var body: some View {
        Text("定期")
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.mutedText)
            .padding(.horizontal, Theme.Spacing.small)
            .padding(.vertical, Theme.Spacing.extraExtraSmall)
            .background(
                Theme.Recording.badgeBackground,
                in: RoundedRectangle(cornerRadius: Theme.Recording.badgeRadius),
            )
    }
}

import SharedLogic
import SwiftUI

/// The needs-review records of the ledger in view on home, below its name
/// and under the scans' band (`Home7.dc.html`): `要確認 2件` with
/// `明細が合計と合わないまま記録したもの`, shown only while any record is
/// marked (`review-status`); choosing it lists them (要確認の記録).
internal struct ReviewStatusBand: View {
    internal let status: ReviewStatus
    internal let action: () -> Void

    // `要確認 2件` in the warning colour over what they are.
    private var texts: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.extraExtraSmall) {
            Text(self.status.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.Scanning.review)
            Text(self.status.detail)
                .font(.caption)
                .foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    internal var body: some View {
        Button(action: self.action) {
            HStack(spacing: Theme.Spacing.small) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.Scanning.review)
                    .accessibilityHidden(true)
                self.texts
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .frame(minHeight: Theme.minimumTapTarget)
            .background(
                Theme.Scanning.review.opacity(Theme.Scanning.mismatchTintOpacity),
                in: RoundedRectangle(cornerRadius: Theme.Scanning.bandRadius),
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Scanning.bandRadius)
                    .strokeBorder(
                        Theme.Scanning.review.opacity(Theme.Scanning.mismatchBorderOpacity),
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.status.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("review-status")
    }
}

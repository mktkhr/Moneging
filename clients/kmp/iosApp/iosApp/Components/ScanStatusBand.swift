import SwiftUI

/// The scans of the ledger in view on home, below its name
/// (`Home5.dc.html`): `読み取り中 1件・確認待ち 2件`, shown only while any
/// scan is in flight or any draft waits (`scan-status`); choosing it lists
/// the scans (レシートの読み取り).
internal struct ScanStatusBand: View {
    internal let text: String
    internal let action: () -> Void

    internal var body: some View {
        Button(action: self.action) {
            HStack(spacing: Theme.Spacing.small) {
                Image(systemName: "scroll")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text(self.text)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .frame(minHeight: Theme.minimumTapTarget)
            .background(
                Theme.accent.opacity(Theme.Scanning.bandTintOpacity),
                in: RoundedRectangle(cornerRadius: Theme.Scanning.bandRadius),
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Scanning.bandRadius)
                    .strokeBorder(Theme.accent.opacity(Theme.Scanning.bandBorderOpacity))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.text)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("scan-status")
    }
}

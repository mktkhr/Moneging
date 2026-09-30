import SwiftUI

/// The notice that photos were accepted for reading
/// (`2枚の読み取りを受け付けました`, `scan-accepted-notice`), shown for a
/// moment above the record button; it takes no touch.
internal struct ScanAcceptedNotice: View {
    internal let text: String

    internal var body: some View {
        Text(self.text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.Scanning.noticeText)
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.small)
            .background(Theme.Scanning.noticeBackground, in: Capsule())
            .allowsHitTesting(false)
            .accessibilityLabel(self.text)
            .accessibilityIdentifier("scan-accepted-notice")
    }
}

import SwiftUI

/// The callout's main button: a filled accent capsule (はじめる, 次へ).
internal struct TourPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled)
    private var isEnabled: Bool

    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, Theme.Spacing.extraLarge)
            .frame(minHeight: Theme.minimumTapTarget)
            .background(
                Theme.accent.opacity(self.isEnabled ? 1 : Theme.disabledOpacity), in: Capsule()
            )
            .opacity(configuration.isPressed ? Theme.pressedOpacity : 1)
    }
}

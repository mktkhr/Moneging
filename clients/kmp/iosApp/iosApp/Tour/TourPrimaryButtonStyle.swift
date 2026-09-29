import SwiftUI

/// The callout's main button: a filled accent capsule (はじめる, 次へ).
///
/// The whole frame takes touches, not only the capsule: at large text
/// sizes the capsule is tall and its corners leave room that SwiftUI's
/// touch matching would give to the neighbouring スキップ.
internal struct TourPrimaryButtonStyle: ButtonStyle {
    /// Whether the button spans the width it is offered (the stacked
    /// layout) instead of hugging its title.
    internal var isFullWidth: Bool = false

    @Environment(\.isEnabled)
    private var isEnabled: Bool

    internal func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, Theme.Spacing.extraLarge)
            .frame(maxWidth: self.isFullWidth ? .infinity : nil)
            .frame(minHeight: Theme.minimumTapTarget)
            .background(
                Theme.accent.opacity(self.isEnabled ? 1 : Theme.disabledOpacity), in: Capsule()
            )
            .opacity(configuration.isPressed ? Theme.pressedOpacity : 1)
            .contentShape(Rectangle())
    }
}

import SwiftUI

/// One filter chip above the search field (`Search2.dc.html`): a menu
/// whose title is the filter's current choice, tinted while it narrows the
/// search, on Liquid Glass.
internal struct SearchFilterChip<Choices: View>: View {
    internal let title: String
    internal let isActive: Bool
    internal let identifier: String
    @ViewBuilder internal let choices: () -> Choices

    internal var body: some View {
        Menu {
            self.choices()
        } label: {
            HStack(spacing: Theme.Spacing.extraSmall) {
                Text(self.title)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(self.isActive ? .semibold : .regular))
            .foregroundStyle(self.isActive ? Theme.accent : Theme.text)
            .padding(.horizontal, Theme.Spacing.medium)
            .frame(minHeight: Theme.minimumTapTarget)
            .glassEffect(
                self.isActive
                    ? .regular.tint(Theme.accentTint).interactive() : .regular.interactive(),
                in: Capsule(),
            )
        }
        .accessibilityIdentifier(self.identifier)
    }
}

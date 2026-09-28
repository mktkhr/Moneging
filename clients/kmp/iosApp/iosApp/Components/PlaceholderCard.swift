import SwiftUI

/// A placeholder section card with a dashed border, matching the
/// mockup's `[今月の残り予算]`-style bracketed placeholders.
internal struct PlaceholderCard: View {
    internal let title: String

    internal var body: some View {
        Text("[\(self.title)]")
            .font(.footnote)
            .foregroundStyle(Theme.mutedText)
            // Sized by its own text plus padding tokens: the real section
            // it stands in for does not exist yet, so no height is assumed.
            .padding(Theme.Spacing.extraLarge)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(
                        Theme.line,
                        style: StrokeStyle(
                            lineWidth: Theme.dashedBorderLineWidth,
                            dash: [Theme.dashedBorderDashLength, Theme.dashedBorderGapLength],
                        ),
                    )
            }
    }
}

#Preview {
    PlaceholderCard(title: "今月の残り予算")
}

import SwiftUI

/// A placeholder section card with a dashed border, matching the
/// mockup's `[今月の残り予算]`-style bracketed placeholders.
internal struct PlaceholderCard: View {
    internal let title: String
    internal let minHeight: CGFloat

    internal var body: some View {
        Text("[\(self.title)]")
            .font(.footnote)
            .foregroundStyle(Theme.mutedText)
            .frame(maxWidth: .infinity, minHeight: self.minHeight)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(
                        Theme.line,
                        style: StrokeStyle(
                            lineWidth: Theme.dashedBorderLineWidth,
                            dash: [Theme.spacing6, Theme.spacing4],
                        ),
                    )
            }
    }
}

#Preview {
    PlaceholderCard(title: "今月の残り予算", minHeight: Theme.budgetCardMinHeight)
}

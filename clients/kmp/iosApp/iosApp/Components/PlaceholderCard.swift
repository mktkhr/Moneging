import SwiftUI

/// A placeholder section card with a dashed border, matching the
/// mockup's `[今月の残り予算]`-style bracketed placeholders.
internal struct PlaceholderCard: View {
    private static let cornerRadius: CGFloat = 20
    private static let borderOpacity: Double = 0.22
    private static let dashLineWidth: CGFloat = 1.5
    private static let dashPatternOn: CGFloat = 6
    private static let dashPatternOff: CGFloat = 4

    internal let title: String
    internal let minHeight: CGFloat

    internal var body: some View {
        Text("[\(self.title)]")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: self.minHeight)
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(
                        .primary.opacity(Self.borderOpacity),
                        style: StrokeStyle(
                            lineWidth: Self.dashLineWidth,
                            dash: [Self.dashPatternOn, Self.dashPatternOff],
                        ),
                    )
            }
    }
}

#Preview {
    PlaceholderCard(title: "今月の残り予算", minHeight: 132)
}

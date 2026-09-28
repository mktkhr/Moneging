import SwiftUI

/// Shared scrollable placeholder body for tabs that do not yet have their
/// own layout (カレンダー, レポート, 予算): enough rows to be worth
/// scrolling, so a UI test can exercise scroll-position retention on any
/// tab, not only ホーム.
internal struct GenericPlaceholderTabContent: View {
    private static let rowCount: Int = 24
    private static let rowSpacing: CGFloat = 8
    private static let rowPadding: CGFloat = 12
    private static let rowCornerRadius: CGFloat = 12
    private static let contentPadding: CGFloat = 16

    internal let screenID: String
    internal let creationCount: Int
    internal let rowTitle: String

    internal var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            TabRootLifecycleMarker(screenID: self.screenID, creationCount: self.creationCount)
            ForEach(1...Self.rowCount, id: \.self) { index in
                Text("\(self.rowTitle) \(index)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Self.rowPadding)
                    .background(
                        Theme.surface,
                        in: RoundedRectangle(cornerRadius: Self.rowCornerRadius),
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.rowCornerRadius)
                            .strokeBorder(Theme.line)
                    }
                    .accessibilityIdentifier("\(self.screenID)-row-\(index)")
            }
        }
        .padding(Self.contentPadding)
    }
}

#Preview {
    ScrollView {
        GenericPlaceholderTabContent(screenID: "calendar", creationCount: 1, rowTitle: "日別の記録")
    }
}

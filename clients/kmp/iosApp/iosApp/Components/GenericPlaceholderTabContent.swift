import SwiftUI

/// Shared scrollable placeholder body for tabs that do not yet have their
/// own layout (カレンダー, レポート, 予算): enough rows to be worth
/// scrolling, so a UI test can exercise scroll-position retention on any
/// tab, not only ホーム.
internal struct GenericPlaceholderTabContent: View {
    private static let rowCount: Int = 24

    internal let screenID: String
    internal let creationCount: Int
    internal let rowTitle: String

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing8) {
            TabRootLifecycleMarker(screenID: self.screenID, creationCount: self.creationCount)
            ForEach(1...Self.rowCount, id: \.self) { index in
                Text("\(self.rowTitle) \(index)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.spacing12)
                    .background(
                        Theme.surface,
                        in: RoundedRectangle(cornerRadius: Theme.radius),
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radius)
                            .strokeBorder(Theme.line)
                    }
                    .accessibilityIdentifier("\(self.screenID)-row-\(index)")
            }
        }
        .padding(Theme.spacing16)
    }
}

#Preview {
    ScrollView {
        GenericPlaceholderTabContent(screenID: "calendar", creationCount: 1, rowTitle: "日別の記録")
    }
}

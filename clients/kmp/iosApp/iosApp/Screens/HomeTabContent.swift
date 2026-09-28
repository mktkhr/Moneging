import SwiftUI

/// ホーム tab root content: placeholder sections for the remaining budget,
/// receipts pending confirmation, and recent records, matching
/// `scratchpad/design/project/OptionB.dc.html`.
internal struct HomeTabContent: View {
    private static let recentRecordCount: Int = 24
    private static let sectionSpacing: CGFloat = 12
    private static let recentListSpacing: CGFloat = 8
    private static let rowPadding: CGFloat = 12
    private static let rowCornerRadius: CGFloat = 12
    private static let rowBorderOpacity: Double = 0.08
    private static let contentPadding: CGFloat = 16
    private static let budgetCardHeight: CGFloat = 132
    private static let pendingCardHeight: CGFloat = 64

    internal let lifecycle: TabRootLifecycle

    internal var body: some View {
        VStack(spacing: Self.sectionSpacing) {
            TabRootLifecycleMarker(screenID: "home", creationCount: self.lifecycle.creationCount)
            PlaceholderCard(title: "今月の残り予算", minHeight: Self.budgetCardHeight)
            PlaceholderCard(title: "読み取り中・確認待ち", minHeight: Self.pendingCardHeight)
            VStack(alignment: .leading, spacing: Self.recentListSpacing) {
                Text("最近の記録")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                ForEach(1...Self.recentRecordCount, id: \.self) { index in
                    Text("記録 \(index)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Self.rowPadding)
                        .background(
                            Theme.background,
                            in: RoundedRectangle(cornerRadius: Self.rowCornerRadius),
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Self.rowCornerRadius)
                                .strokeBorder(.primary.opacity(Self.rowBorderOpacity))
                        }
                        .accessibilityIdentifier("home-recent-record-\(index)")
                }
            }
        }
        .padding(Self.contentPadding)
    }
}

#Preview {
    ScrollView {
        HomeTabContent(lifecycle: TabRootLifecycle(screenID: "home"))
    }
}

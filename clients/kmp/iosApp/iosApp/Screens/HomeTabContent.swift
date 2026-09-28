import SwiftUI

/// ホーム tab root content: placeholder sections for the remaining budget,
/// receipts pending confirmation, and recent records, matching
/// `scratchpad/design/project/OptionB.dc.html`.
internal struct HomeTabContent: View {
    private static let recentRecordCount: Int = 24

    // Held here (the tab root's own content view), not at `RootView`: this
    // is where docs/handbook/architecture.md rule 3 puts screen state, and
    // `RootView` itself is created once at the app root, so this state
    // object is created exactly once for as long as `HomeTabContent` is
    // never recreated. See `testTabRootsAreNotRecreatedAcrossManySwitches`
    // (iosAppUITests) for how that is verified on the simulator.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "home")

    internal var body: some View {
        VStack(spacing: Theme.spacing12) {
            TabRootLifecycleMarker(screenID: "home", creationCount: self.lifecycle.creationCount)
            PlaceholderCard(title: "今月の残り予算", minHeight: Theme.budgetCardMinHeight)
            PlaceholderCard(title: "読み取り中・確認待ち", minHeight: Theme.pendingCardMinHeight)
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                Text("最近の記録")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.mutedText)
                ForEach(1...Self.recentRecordCount, id: \.self) { index in
                    Text("記録 \(index)")
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
                        .accessibilityIdentifier("home-recent-record-\(index)")
                }
            }
        }
        .padding(Theme.spacing16)
    }
}

#Preview {
    ScrollView {
        HomeTabContent()
    }
}

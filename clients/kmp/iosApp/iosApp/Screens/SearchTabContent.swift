import SwiftUI

/// 検索 tab root: its own `NavigationStack` with a search field and
/// placeholder results, bound to `AppRouter.searchPath` like every other
/// tab.
internal struct SearchTabContent: View {
    private static let suggestionCount: Int = 20

    internal let path: Binding<NavigationPath>

    // Held here (the tab root's own content view), not at `RootView`; see
    // `HomeTabContent`'s own doc comment on `lifecycle` for why. 検索 uses
    // `Tab(role: .search)`, which an earlier version of this file suspected
    // of reconstructing its content on every activation (unlike the four
    // plain tabs) and hoisted this state to `RootView` to work around.
    // Verified on the simulator (`testTabRootsAreNotRecreatedAcrossManySwitches`,
    // iosAppUITests: `search-creation-count` stays "1" across many
    // tab-switch round trips) that this is not the case, so this state
    // lives here like every other tab's.
    @State private var lifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "search")

    @State private var query: String = ""

    internal var body: some View {
        NavigationStack(path: self.path) {
            List {
                TabRootLifecycleMarker(
                    screenID: "search",
                    creationCount: self.lifecycle.creationCount,
                )
                ForEach(1...Self.suggestionCount, id: \.self) { index in
                    Text("検索候補 \(index)")
                        .accessibilityIdentifier("search-row-\(index)")
                }
            }
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: self.$query, prompt: "記録を検索")
            .appNavigationDestinations()
        }
    }
}

#Preview {
    SearchTabContent(path: .constant(NavigationPath()))
}

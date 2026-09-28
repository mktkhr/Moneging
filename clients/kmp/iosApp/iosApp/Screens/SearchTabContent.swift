import SwiftUI

/// 検索 tab root: its own `NavigationStack` with a search field and
/// placeholder results, bound to `AppRouter.searchPath` like every other
/// tab.
///
/// Unlike every other tab's own content view (`HomeTabContent`,
/// `CalendarTabContent`, `ReportTabContent`, `BudgetTabContent`, each of
/// which owns its own `lifecycle` `@State`), this one receives `lifecycle`
/// from `RootView` instead. `Tab(value:role: .search)` was verified on the
/// simulator (`testTabRootsAreNotRecreatedAcrossManySwitches`,
/// iosAppUITests) to reconstruct its content on every activation: with
/// `lifecycle` held here as `@State`, `search-tab-root`'s creation count climbed to
/// "5" after three round trips through every tab, where every other tab's
/// counter stayed "1". Hoisting it to `RootView` (created once at the app
/// root, so never recreated itself) keeps this tab's state alive across
/// switches the same way the others' local `@State` does -
/// `search-tab-root`'s creation count stays "1" with that arrangement, confirmed the
/// same way.
internal struct SearchTabContent: View {
    private static let suggestionCount: Int = 20

    internal let path: Binding<NavigationPath>
    internal let lifecycle: TabRootLifecycle

    @State private var query: String = ""

    internal var body: some View {
        NavigationStack(path: self.path) {
            List {
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
        .tabRootLifecycleHook(screenID: "search", creationCount: self.lifecycle.creationCount)
    }
}

#Preview {
    SearchTabContent(
        path: .constant(NavigationPath()),
        lifecycle: TabRootLifecycle(screenID: "search"),
    )
}

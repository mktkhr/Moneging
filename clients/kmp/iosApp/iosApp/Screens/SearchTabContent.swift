import SwiftUI

/// 検索 tab root: its own `NavigationStack` with a search field and
/// placeholder results, bound to `AppRouter.searchPath` like every other
/// tab.
internal struct SearchTabContent: View {
    private static let suggestionCount: Int = 20

    internal let path: Binding<NavigationPath>
    internal let lifecycle: TabRootLifecycle

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
    SearchTabContent(
        path: .constant(NavigationPath()),
        lifecycle: TabRootLifecycle(screenID: "search"),
    )
}

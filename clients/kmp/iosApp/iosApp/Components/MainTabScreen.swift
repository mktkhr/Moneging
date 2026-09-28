import SwiftUI

/// A main tab's root, wrapping a `NavigationStack` and the shared header.
///
/// Bound to that tab's path, wrapped around the tab's scrollable
/// placeholder content and the shared header (`TabHeaderModifier`). The
/// floating 記録する button lives once at the app root (`RootView`), not
/// per tab, so its sheet is only ever presented once regardless of which
/// tab is active.
internal struct MainTabScreen<Content: View>: View {
    internal let path: Binding<NavigationPath>
    @ViewBuilder internal let content: () -> Content

    internal var body: some View {
        NavigationStack(path: self.path) {
            ScrollView {
                self.content()
            }
            .background(Theme.background)
            .tabHeader()
            .appNavigationDestinations()
        }
    }
}

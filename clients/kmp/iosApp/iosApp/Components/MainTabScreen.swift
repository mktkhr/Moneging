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
            // Measured before this tab root's own `.safeAreaInset` below,
            // so it reads the tab bar's own (system) bottom safe area, not
            // the space that `.safeAreaInset` reserves on top of it.
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: TabBarBottomInsetPreferenceKey.self,
                            value: proxy.safeAreaInsets.bottom,
                        )
                },
            )
            // Reserves space below the tab root's own scrollable content so
            // its last row is never covered by the floating 記録する button
            // (`RootView`'s overlay): the button's own footprint (diameter
            // plus the same margin `RootView` gives it above the tab bar).
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: Theme.recordButtonDiameter + Theme.spacing16)
            }
        }
    }
}

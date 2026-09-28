import SwiftUI

/// A main tab's root, wrapping a `NavigationStack` and the shared header.
///
/// Bound to that tab's path, wrapped around the tab's scrollable
/// placeholder content and the shared header (`TabHeaderModifier`), with
/// the floating 記録する button floating above the tab bar. The sheet that
/// button opens lives once at the app root (`RootView`), so it is only
/// ever presented once regardless of which tab is active.
internal struct MainTabScreen<Content: View>: View {
    internal let path: Binding<NavigationPath>
    @ViewBuilder internal let content: () -> Content

    @Environment(AppRouter.self)
    private var router: AppRouter

    internal var body: some View {
        NavigationStack(path: self.path) {
            ScrollView {
                self.content()
            }
            .background(Theme.background)
            .tabHeader()
            .appNavigationDestinations()
            // Places the floating 記録する button in the tab root's own
            // bottom safe-area inset, right-aligned. Inside a tab, the tab
            // bar (whatever its current height: Liquid Glass's
            // collapsed/expanded states, Dynamic Type, device, orientation)
            // is already part of the bottom safe area, so the inset sits
            // above the whole tab bar - including the separate 検索 button -
            // without measuring anything; the padding is only the deliberate
            // gap around the button. The inset also shrinks the scroll
            // view's safe area by exactly the button's footprint, so the last
            // row can always scroll clear of it.
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                if self.router.isRecordButtonVisible {
                    FloatingRecordButton {
                        self.router.isRecordSheetPresented = true
                    }
                    .padding([.trailing, .bottom], Theme.Spacing.large)
                }
            }
        }
    }
}

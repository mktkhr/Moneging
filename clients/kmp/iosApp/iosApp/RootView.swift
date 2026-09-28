import SharedLogic
import SwiftUI

/// The app's root: a standard `TabView` with five tabs.
///
/// Each tab owns its own `NavigationStack` bound to `AppRouter`. The
/// floating 記録する button and its sheet live here once, shared by the
/// four main tabs, so switching tabs never duplicates or recreates them.
internal struct RootView: View {
    @Environment(AppRouter.self)
    private var router: AppRouter

    // Held here, not inside `SearchTabContent` itself (unlike every other
    // tab's own content view - see `HomeTabContent`'s doc comment on its
    // own `lifecycle`): `Tab(role: .search)` was verified on the simulator
    // (`testTabRootsAreNotRecreatedAcrossManySwitches`, iosAppUITests) to
    // reconstruct its content on every activation, unlike the four plain
    // tabs - with this state held inside `SearchTabContent` instead,
    // `search-creation-count` climbed to "5" after three round trips
    // through every tab. `RootView` is itself created once at the app
    // root, so holding it here keeps it alive regardless.
    @State private var searchLifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "search")

    internal var body: some View {
        @Bindable var router: AppRouter = self.router

        GeometryReader { proxy in
            let sheetMaxHeight: CGFloat = proxy.size.height - proxy.safeAreaInsets.top
            self.tabs(router: router, sheetMaxHeight: sheetMaxHeight)
        }
    }

    @ViewBuilder
    private func tabs(router: AppRouter, sheetMaxHeight: CGFloat) -> some View {
        @Bindable var router: AppRouter = router

        TabView(selection: $router.selectedTab) {
            Tab("ホーム", systemImage: "house", value: AppTab.home) {
                MainTabScreen(path: $router.homePath) {
                    HomeTabContent()
                }
            }
            Tab("カレンダー", systemImage: "calendar", value: AppTab.calendar) {
                MainTabScreen(path: $router.calendarPath) {
                    CalendarTabContent()
                }
            }
            Tab("レポート", systemImage: "chart.bar", value: AppTab.report) {
                MainTabScreen(path: $router.reportPath) {
                    ReportTabContent()
                }
            }
            Tab("予算", systemImage: "creditcard", value: AppTab.budget) {
                MainTabScreen(path: $router.budgetPath) {
                    BudgetTabContent()
                }
            }
            Tab(value: AppTab.search, role: .search) {
                SearchTabContent(path: $router.searchPath, lifecycle: self.searchLifecycle)
            } label: {
                Label("検索", systemImage: "magnifyingglass")
            }
        }
        .tint(Theme.accent)
        .overlay(alignment: .bottomTrailing) {
            // `.overlay` on a `TabView` lays out within its safe area, so
            // this sits just above the tab bar automatically (whatever the
            // tab bar's own current height is - Liquid Glass's
            // collapsed/expanded states, Dynamic Type, device); this
            // padding is only the deliberate visual gap above that, not a
            // stand-in for the tab bar's height. `MainTabScreen`'s
            // `.safeAreaInset` reserves exactly this same footprint
            // (`Theme.recordButtonDiameter + Theme.spacing16`) below each
            // tab's scroll content, so the two stay consistent.
            if router.isRecordButtonVisible {
                FloatingRecordButton {
                    router.isRecordSheetPresented = true
                }
                .padding(.trailing, Theme.spacing16)
                .padding(.bottom, Theme.spacing16)
            }
        }
        .sheet(isPresented: $router.isRecordSheetPresented) {
            RecordMenuSheet { option in
                router.chooseRecordOption(option)
            }
            .fittedSheet(maxHeight: sheetMaxHeight)
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .environment(SharedStateStore(appState: sharedAppState()))
}

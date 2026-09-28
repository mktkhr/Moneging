import SharedLogic
import SwiftUI

/// The app's root: a standard `TabView` with five tabs.
///
/// Each tab owns its own `NavigationStack` bound to `AppRouter`. The
/// 記録する sheet lives here once, shared by the four main tabs, so
/// switching tabs never duplicates or recreates it; the floating button
/// that opens it is placed by each main tab's own root (`MainTabScreen`),
/// where the tab bar is already part of the safe area.
internal struct RootView: View {
    @Environment(AppRouter.self)
    private var router: AppRouter

    // Held here, not inside `SearchTabContent` itself (unlike every other
    // tab's own content view - see `HomeTabContent`'s doc comment on its
    // own `lifecycle`): `Tab(role: .search)` was verified on the simulator
    // (`testTabRootsAreNotRecreatedAcrossTabSwitches`, TabNavigationUITests) to
    // reconstruct its content on every activation, unlike the four plain
    // tabs - with this state held inside `SearchTabContent` instead,
    // `search-tab-root`'s creation count climbed to "5" after three round trips
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

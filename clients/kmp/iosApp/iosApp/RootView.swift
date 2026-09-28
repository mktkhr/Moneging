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

    /// The tab bar's own current height, read back from `MainTabScreen`
    /// through `TabBarBottomInsetPreferenceKey` (its safe-area inset is
    /// exactly the tab bar's reserved space) - never hard-coded, since the
    /// tab bar's height varies (Liquid Glass's collapsed/expanded states,
    /// Dynamic Type, device).
    @State private var tabBarBottomInset: CGFloat = 0

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
                SearchTabContent(path: $router.searchPath)
            } label: {
                Label("検索", systemImage: "magnifyingglass")
            }
        }
        .tint(Theme.accent)
        .onPreferenceChange(TabBarBottomInsetPreferenceKey.self) { newValue in
            self.tabBarBottomInset = newValue
        }
        .overlay(alignment: .bottomTrailing) {
            if router.isRecordButtonVisible {
                FloatingRecordButton {
                    router.isRecordSheetPresented = true
                }
                .padding(.trailing, Theme.spacing16)
                .padding(.bottom, self.tabBarBottomInset + Theme.spacing16)
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

import SharedLogic
import SwiftUI

/// The app's root: a standard `TabView` with five tabs.
///
/// Each tab owns its own `NavigationStack` bound to `AppRouter`. The
/// floating 記録する button and its sheet live here once, shared by the
/// four main tabs, so switching tabs never duplicates or recreates them.
internal struct RootView: View {
    private static let recordButtonTrailingInset: CGFloat = 16
    private static let recordButtonBottomInset: CGFloat = 78

    @Environment(AppRouter.self)
    private var router: AppRouter

    internal var body: some View {
        @Bindable var router: AppRouter = self.router

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
        .overlay(alignment: .bottomTrailing) {
            if router.selectedTab != .search {
                FloatingRecordButton {
                    router.isRecordSheetPresented = true
                }
                .padding(.trailing, Self.recordButtonTrailingInset)
                .padding(.bottom, Self.recordButtonBottomInset)
            }
        }
        .sheet(isPresented: $router.isRecordSheetPresented) {
            RecordMenuSheet { option in
                router.chooseRecordOption(option)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .environment(SharedStateStore(viewModel: sharedAppViewModel()))
}

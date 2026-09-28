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

    // Held here, not inside each tab's own content view: `Tab(role:
    // .search)` has been observed to reconstruct its content on every
    // activation (unlike the four plain tabs), which would otherwise
    // recreate `searchLifecycle` on every switch to 検索. Hoisting every
    // tab root's state to `RootView`, which is itself created once at the
    // app root, keeps all five at a single creation regardless.
    @State private var homeLifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "home")
    @State private var calendarLifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "calendar")
    @State private var reportLifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "report")
    @State private var budgetLifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "budget")
    @State private var searchLifecycle: TabRootLifecycle = TabRootLifecycle(screenID: "search")

    // The 記録する sheet's content height, measured once from a hidden
    // copy rendered in ordinary (non-modal) layout below - see
    // `measureHeight(into:)`'s and `FittedSheetModifier`'s doc comments
    // for why measurement happens here rather than inside the sheet
    // itself.
    @State private var recordSheetHeight: CGFloat?

    internal var body: some View {
        @Bindable var router: AppRouter = self.router

        TabView(selection: $router.selectedTab) {
            Tab("ホーム", systemImage: "house", value: AppTab.home) {
                MainTabScreen(path: $router.homePath) {
                    HomeTabContent(lifecycle: self.homeLifecycle)
                }
            }
            Tab("カレンダー", systemImage: "calendar", value: AppTab.calendar) {
                MainTabScreen(path: $router.calendarPath) {
                    CalendarTabContent(lifecycle: self.calendarLifecycle)
                }
            }
            Tab("レポート", systemImage: "chart.bar", value: AppTab.report) {
                MainTabScreen(path: $router.reportPath) {
                    ReportTabContent(lifecycle: self.reportLifecycle)
                }
            }
            Tab("予算", systemImage: "creditcard", value: AppTab.budget) {
                MainTabScreen(path: $router.budgetPath) {
                    BudgetTabContent(lifecycle: self.budgetLifecycle)
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
            if router.isRecordButtonVisible {
                FloatingRecordButton {
                    router.isRecordSheetPresented = true
                }
                .padding(.trailing, Self.recordButtonTrailingInset)
                .padding(.bottom, Self.recordButtonBottomInset)
            }
        }
        .background {
            // Invisible: exists only so `measureHeight(into:)` can read the
            // record sheet's true content height once, in ordinary layout,
            // before the sheet below ever presents it.
            RecordMenuSheet { _ in
                // No-op: this copy is never shown, so it never chooses.
            }
            .measureHeight(into: self.$recordSheetHeight)
            .hidden()
            MeasuredHeightMarker(screenID: "record-sheet", height: self.recordSheetHeight)
        }
        .sheet(isPresented: $router.isRecordSheetPresented) {
            RecordMenuSheet { option in
                router.chooseRecordOption(option)
            }
            .fittedSheet(height: self.recordSheetHeight)
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .environment(SharedStateStore(viewModel: sharedAppViewModel()))
}

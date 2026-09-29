import SharedLogic
import SwiftUI

/// The app's root: a standard `TabView` with five tabs, and the onboarding
/// tour over it while one is shown.
///
/// Each tab owns its own `NavigationStack` bound to `AppRouter`. The
/// 記録する sheet lives here once, shared by the four main tabs, so
/// switching tabs never duplicates or recreates it; the floating button
/// that opens it is placed by each main tab's own root (`MainTabScreen`),
/// where the tab bar is already part of the safe area.
internal struct RootView: View {
    @Environment(AppRouter.self)
    private var router: AppRouter

    @Environment(SharedStateStore.self)
    private var store: SharedStateStore

    // Where the tour's targets are; reported by ホーム's root.
    @State private var tourLayout: TourLayout = TourLayout()

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

        // Nothing is shown until the ledgers and the tour's progress are
        // read, so the first frame already shows the right ledger and tour.
        if self.store.isLoaded {
            GeometryReader { proxy in
                let sheetMaxHeight: CGFloat = proxy.size.height - proxy.safeAreaInsets.top
                self.tabs(router: router, sheetMaxHeight: sheetMaxHeight)
            }
            .environment(self.tourLayout)
            .overlay {
                if let tour = self.store.tour {
                    TourOverlay(tour: tour)
                        .environment(self.tourLayout)
                }
            }
            .onChange(of: self.store.tour?.step, initial: true) { _, step in
                if step != nil {
                    self.router.showHomeRoot()
                }
            }
            .alert(
                "エラー",
                isPresented: Binding(
                    get: { self.store.shownErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            self.store.dismissError()
                        }
                    },
                ),
            ) {
                Button("OK") {
                    self.store.dismissError()
                }
            } message: {
                Text(self.store.shownErrorMessage ?? "")
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
        }
    }

    @ViewBuilder
    private func tabs(router: AppRouter, sheetMaxHeight: CGFloat) -> some View {
        @Bindable var router: AppRouter = router

        TabView(selection: $router.selectedTab) {
            Tab("ホーム", systemImage: "house", value: AppTab.home) {
                MainTabScreen(path: $router.homePath, isTourHost: true) {
                    HomeTabContent()
                }
            }
            Tab("カレンダー", systemImage: "calendar", value: AppTab.calendar) {
                MainTabScreen(path: $router.calendarPath, isTourHost: false) {
                    CalendarTabContent()
                }
            }
            Tab("レポート", systemImage: "chart.bar", value: AppTab.report) {
                MainTabScreen(path: $router.reportPath, isTourHost: false) {
                    ReportTabContent()
                }
            }
            Tab("予算", systemImage: "creditcard", value: AppTab.budget) {
                MainTabScreen(path: $router.budgetPath, isTourHost: false) {
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
        .sheet(isPresented: $router.isAddLedgerSheetPresented) {
            AddLedgerSheet()
        }
    }
}

#Preview {
    RootView()
        .environment(AppRouter())
        .environment(SharedStateStore(appState: sharedAppState()))
}

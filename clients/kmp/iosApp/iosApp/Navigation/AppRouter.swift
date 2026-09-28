import Observation
import SwiftUI

/// App-wide navigation state: each tab's `NavigationPath`, the selected
/// tab, and the record sheet's presentation flag.
///
/// Created once at the app root (`MonegingApp`) and shared through the
/// environment, so switching tabs never recreates a tab's `NavigationStack`
/// or resets its path (docs/handbook/architecture.md, rule 2).
@Observable
internal final class AppRouter {
    /// The currently selected tab.
    internal var selectedTab: AppTab = .home
    /// ホーム tab's push-navigation path.
    internal var homePath: NavigationPath = NavigationPath()
    /// カレンダー tab's push-navigation path.
    internal var calendarPath: NavigationPath = NavigationPath()
    /// レポート tab's push-navigation path.
    internal var reportPath: NavigationPath = NavigationPath()
    /// 予算 tab's push-navigation path.
    internal var budgetPath: NavigationPath = NavigationPath()
    /// 検索 tab's push-navigation path.
    internal var searchPath: NavigationPath = NavigationPath()
    /// Whether the 記録する sheet is presented.
    internal var isRecordSheetPresented: Bool = false

    /// Appends `route` to the currently selected tab's path.
    internal func push(_ route: Route) {
        switch self.selectedTab {
        case .budget:
            self.budgetPath.append(route)

        case .calendar:
            self.calendarPath.append(route)

        case .home:
            self.homePath.append(route)

        case .report:
            self.reportPath.append(route)

        case .search:
            self.searchPath.append(route)
        }
    }

    /// Dismisses the 記録する sheet, then pushes a placeholder screen.
    ///
    /// The screen pushed is `option`'s, appended to the currently selected
    /// tab's path.
    internal func chooseRecordOption(_ option: RecordOption) {
        self.isRecordSheetPresented = false
        self.push(.recordOption(option))
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}

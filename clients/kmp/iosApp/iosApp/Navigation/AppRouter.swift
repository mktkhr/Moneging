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

    /// Whether the floating 記録する button should show.
    ///
    /// True only on a main tab's own root screen (nothing pushed on top of
    /// it): pushing any `Route` onto the active tab (e.g. 設定 from ホーム)
    /// hides the button until the user pops back to that tab's root. 検索
    /// never shows it. Driven from the navigation state (each tab's own
    /// `NavigationPath`), not merely from `selectedTab`.
    internal var isRecordButtonVisible: Bool {
        switch self.selectedTab {
        case .budget:
            self.budgetPath.isEmpty

        case .calendar:
            self.calendarPath.isEmpty

        case .home:
            self.homePath.isEmpty

        case .report:
            self.reportPath.isEmpty

        case .search:
            false
        }
    }

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

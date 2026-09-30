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
    /// Whether the 家計簿を追加 sheet is presented.
    internal var isAddLedgerSheetPresented: Bool = false
    /// The entry or edit sheet presented, or `nil`.
    internal var entrySheet: EntrySheetRequest?
    /// What opens once the 記録する sheet has closed: the option chosen in it.
    internal var optionPendingOnRecordSheet: RecordOption?
    /// The way of handing over receipt photos to open now (the document
    /// scanner or the photo library), or `nil`.
    internal var receiptCapture: RecordOption?
    /// The draft whose sheet is presented, or `nil`.
    internal var draftSheet: DraftSheetRequest?

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

    /// Removes the top screen of the currently selected tab's path.
    internal func pop() {
        switch self.selectedTab {
        case .budget:
            if !self.budgetPath.isEmpty {
                self.budgetPath.removeLast()
            }

        case .calendar:
            if !self.calendarPath.isEmpty {
                self.calendarPath.removeLast()
            }

        case .home:
            if !self.homePath.isEmpty {
                self.homePath.removeLast()
            }

        case .report:
            if !self.reportPath.isEmpty {
                self.reportPath.removeLast()
            }

        case .search:
            if !self.searchPath.isEmpty {
                self.searchPath.removeLast()
            }
        }
    }

    /// Shows ホーム's root screen, where the tour runs: selects the tab and
    /// returns every tab to its root, closing any sheet.
    internal func showHomeRoot() {
        self.isRecordSheetPresented = false
        self.isAddLedgerSheetPresented = false
        self.entrySheet = nil
        self.draftSheet = nil
        self.receiptCapture = nil
        self.selectedTab = .home
        self.homePath = NavigationPath()
        self.calendarPath = NavigationPath()
        self.reportPath = NavigationPath()
        self.budgetPath = NavigationPath()
        self.searchPath = NavigationPath()
    }

    /// Dismisses the 記録する sheet; what `option` opens (the entry sheet,
    /// the document scanner or the photo library) then opens
    /// (`recordSheetDidDismiss()`).
    internal func chooseRecordOption(_ option: RecordOption) {
        self.optionPendingOnRecordSheet = option
        self.isRecordSheetPresented = false
    }

    /// Opens what the option chosen in the 記録する sheet opens, once the
    /// sheet has closed.
    internal func recordSheetDidDismiss() {
        guard let option = self.optionPendingOnRecordSheet else {
            return
        }
        self.optionPendingOnRecordSheet = nil
        switch option {
        case .manual:
            self.entrySheet = .new(photoId: nil)

        case .photoPick, .receiptScan:
            self.receiptCapture = option
        }
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}

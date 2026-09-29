import SwiftUI

/// Resolves a `Route` to the screen it pushes.
internal struct RouteDestination: View {
    internal let route: Route

    internal var body: some View {
        switch self.route {
        case .notifications:
            PlaceholderScreen(title: "お知らせ", subtitle: PlaceholderScreen.defaultSubtitle)

        case .renameLedger(let ledgerId):
            RenameLedgerScreen(ledgerId: ledgerId)

        case .recordOption(let option):
            PlaceholderScreen(title: option.title, subtitle: option.subtitle)

        case .settings:
            SettingsScreen()

        case .settingsDetail(let item):
            PlaceholderScreen(title: item.label, subtitle: PlaceholderScreen.defaultSubtitle)
        }
    }
}

extension View {
    /// Registers every `Route` this shell can push, so each tab's
    /// `NavigationStack` resolves them the same way.
    internal func appNavigationDestinations() -> some View {
        self.navigationDestination(for: Route.self) { route in
            RouteDestination(route: route)
        }
    }
}

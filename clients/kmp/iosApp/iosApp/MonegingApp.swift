import SharedLogic
import SwiftUI

@main
internal struct MonegingApp: App {
    @State private var router: AppRouter
    @State private var store: SharedStateStore

    internal var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.router)
                .environment(self.store)
        }
    }

    internal init() {
        // The shared Koin container must be running before `SharedStateStore`
        // resolves the shared `AppViewModel` from it, so this runs first.
        doInitKoin()
        self._router = State(wrappedValue: AppRouter())
        self._store = State(wrappedValue: SharedStateStore(viewModel: sharedAppViewModel()))
        Theme.applyTabBarAppearance()
    }
}

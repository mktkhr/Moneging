import SharedLogic
import SwiftUI

@main
internal struct MonegingApp: App {
    @State private var router: AppRouter
    @State private var store: SharedStateStore
    @State private var ledgerStore: LedgerStore

    internal var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.router)
                .environment(self.store)
                .environment(self.ledgerStore)
        }
    }

    internal init() {
        #if DEBUG
            // Before the store opens: a UI test may start the app as freshly installed.
            UITestLaunchData.resetIfAsked()
        #endif
        // The shared Koin container must be running before `SharedStateStore`
        // resolves the shared `AppState` from it, so this runs first.
        #if DEBUG
            // A UI test's today (`-AcceptanceToday yyyy-MM-dd`), else the device's clock.
            UITestLaunchData.initKoin()
        #else
            doInitKoin()
        #endif
        #if DEBUG
            UITestAnimationSwitch.applyLaunchArgument()
            // Before the app state reads the device: ledgers for UI tests past the onboarding.
            UITestLaunchData.seedIfAsked()
        #endif
        self._router = State(wrappedValue: AppRouter())
        self._store = State(wrappedValue: SharedStateStore(appState: sharedAppState()))
        self._ledgerStore = State(
            wrappedValue: LedgerStore(ledgerData: sharedLedgerData(), editor: sharedLedgerEditor()),
        )
    }
}

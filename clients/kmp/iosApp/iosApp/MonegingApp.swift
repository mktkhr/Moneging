import SharedLogic
import SwiftUI

@main
internal struct MonegingApp: App {
    @State private var router: AppRouter
    @State private var store: SharedStateStore
    @State private var ledgerStore: LedgerStore
    @State private var scanStore: ScanStore

    internal var body: some Scene {
        WindowGroup {
            RootView()
                .environment(self.router)
                .environment(self.store)
                .environment(self.ledgerStore)
                .environment(self.scanStore)
                // Japanese only (PRODUCT.md §5): dates read `2026年2月14日`
                // whatever the device's language, on the product's calendar.
                .environment(\.locale, IsoDate.locale)
                .environment(\.calendar, IsoDate.calendar)
                .environment(\.timeZone, IsoDate.timeZone)
        }
    }

    internal init() {
        #if DEBUG
            // Before the store opens: a UI test may start the app as freshly installed.
            UITestLaunchData.resetIfAsked()
        #endif
        // The shared Koin container must be running before `SharedStateStore`
        // resolves the shared `AppState` from it, so this runs first.
        let reader: SystemReceiptReader = SystemReceiptReader()
        #if DEBUG
            // A UI test's today (`-AcceptanceToday yyyy-MM-dd`), else the device's clock.
            UITestLaunchData.initKoin(reader: reader)
        #else
            doInitKoin(reader: reader)
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
        self._scanStore = State(
            wrappedValue: ScanStore(
                scanData: sharedScanData(),
                editor: sharedScanEditor(),
                progressSurface: Self.progressSurface(),
            ),
        )
    }

    /// Where the scans in flight are shown outside the app: the Live
    /// Activity, or a UI test's stand-in.
    private static func progressSurface() -> any ScanProgressSurface {
        #if DEBUG
            if let fake = UITestScanning.progressSurface {
                return fake
            }
        #endif
        return LiveActivityProgressSurface()
    }
}

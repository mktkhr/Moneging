import Observation

/// A tab root's per-screen state, held once in `@State` for the app's
/// lifetime.
///
/// Records its own creation count so a UI test can assert it stays at 1
/// across tab switches.
@Observable
internal final class TabRootLifecycle {
    /// How many times a state object with this `screenID` has been created.
    ///
    /// Stays 1 as long as the tab root is never recreated.
    internal let creationCount: Int

    internal init(screenID: String) {
        self.creationCount = ScreenLifecycleTracker.recordCreation(of: screenID)
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}

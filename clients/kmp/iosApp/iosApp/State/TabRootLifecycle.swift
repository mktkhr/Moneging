import Observation

/// A tab root's per-screen state, held once in `@State` for the app's
/// lifetime.
///
/// Records its own creation count so a UI test can assert it stays at 1
/// across tab switches. `@MainActor`: created from a SwiftUI `@State`
/// initializer, always on the main actor, matching
/// `ScreenLifecycleTracker`'s own isolation.
@MainActor
@Observable
internal final class TabRootLifecycle {
    /// How many times a state object with this `screenID` has been created.
    ///
    /// Stays 1 as long as the tab root is never recreated. Always 0 in a
    /// release build: the counting itself (`ScreenLifecycleTracker`) only
    /// compiles in `DEBUG` - see that type's own doc comment.
    internal let creationCount: Int

    internal init(screenID: String) {
        #if DEBUG
            self.creationCount = ScreenLifecycleTracker.recordCreation(of: screenID)
        #else
            self.creationCount = 0
        #endif
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}

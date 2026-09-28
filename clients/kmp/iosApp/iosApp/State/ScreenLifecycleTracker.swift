#if DEBUG
    /// Counts how many times each tab root's state object has been created.
    ///
    /// Keyed by screen id. Lets XCUITest assert that switching tabs never
    /// recreates a tab root's `@State` object (see
    /// `docs/handbook/architecture.md`, rule 3); the count is only ever
    /// shown to the user interface in debug builds (see
    /// `TabRootLifecycleHook`), so the counting itself compiles only in
    /// debug builds too - release builds carry neither the storage nor the
    /// bookkeeping.
    ///
    /// `@MainActor`: every `TabRootLifecycle` this tracks is itself created
    /// from a SwiftUI `@State` initializer, which always runs on the main
    /// actor, so this shared mutable dictionary only ever needs to be safe
    /// there.
    @MainActor
    internal enum ScreenLifecycleTracker {
        private static var creationCounts: [String: Int] = [:]

        /// Records a creation for `screenID` and returns the running total.
        internal static func recordCreation(of screenID: String) -> Int {
            let nextCount: Int = (self.creationCounts[screenID] ?? 0) + 1
            self.creationCounts[screenID] = nextCount
            return nextCount
        }
    }
#endif

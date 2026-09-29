#if DEBUG
    import Foundation
    import SharedLogic

    /// The device data a UI test starts the app with.
    ///
    /// Chosen by launch argument, read through the argument domain of
    /// `UserDefaults`:
    ///
    /// - `-AcceptanceResetData YES`: the app starts as freshly installed:
    ///   the database, the photos, the ledger in view and the tour's
    ///   progress are deleted before anything reads them.
    /// - `-UITestSeedLedgers YES`: the same, then the ledgers 家計 (in view)
    ///   and サブ家計簿 exist and the tour is finished, for the product's UI
    ///   tests that start past the onboarding.
    ///
    /// Compiled in debug builds only: release builds never read the flags.
    @MainActor
    internal enum UITestLaunchData {
        private static let resetKey: String = "AcceptanceResetData"
        private static let seedKey: String = "UITestSeedLedgers"
        private static let seededLedgerNames: [String] = ["家計", "サブ家計簿"]

        private static var isSeedAsked: Bool {
            UserDefaults.standard.bool(forKey: Self.seedKey)
        }

        /// Deletes the app's data when a launch argument asks for a fresh
        /// install; must run before the shared container starts.
        internal static func resetIfAsked() {
            guard UserDefaults.standard.bool(forKey: Self.resetKey) || Self.isSeedAsked else {
                return
            }
            resetLocalDataForUiTests()
        }

        /// Creates the UI tests' ledgers when a launch argument asks for
        /// them; must run after the shared container starts and before the
        /// app state is resolved.
        internal static func seedIfAsked() {
            guard Self.isSeedAsked else {
                return
            }
            seedLedgersForUiTests(names: Self.seededLedgerNames)
        }
    }
#endif

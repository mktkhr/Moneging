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
    /// - `-AcceptanceToday yyyy-MM-dd`: the app's clock reads that date at
    ///   12:00 in Asia/Tokyo on launch, and advances from there.
    /// - `-UITestSeedTransactions YES` (with `-UITestSeedLedgers YES`): 家計
    ///   also holds 24 expenses of today, memos `記録01` to `記録24`, for the
    ///   product's UI tests that scroll ホーム.
    ///
    /// Compiled in debug builds only: release builds never read the flags.
    @MainActor
    internal enum UITestLaunchData {
        private static let resetKey: String = "AcceptanceResetData"
        private static let seedKey: String = "UITestSeedLedgers"
        private static let seedTransactionsKey: String = "UITestSeedTransactions"
        private static let todayKey: String = "AcceptanceToday"
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

        /// Starts the shared container, on the injected today when a launch
        /// argument gives one, reading receipts as `UITestScanning` chooses.
        internal static func initKoin(reader: SystemReceiptReader) {
            doInitKoinForUiTests(
                isoDate: UserDefaults.standard.string(forKey: Self.todayKey),
                reader: reader,
                scannerFixtures: UITestScanning.fixturesDirectory,
                isJobStepping: UITestScanning.isJobStepping,
                installer: UITestScanning.moduleInstaller,
            )
            if UITestScanning.isPhotoReadingEnabled {
                enablePhotoReadingForUiTests()
            }
        }

        /// Creates the UI tests' ledgers (and transactions) when a launch
        /// argument asks for them; must run after the shared container
        /// starts and before the app state is resolved.
        internal static func seedIfAsked() {
            guard Self.isSeedAsked else {
                return
            }
            seedLedgersForUiTests(
                names: Self.seededLedgerNames,
                withTransactions: UserDefaults.standard.bool(forKey: Self.seedTransactionsKey),
            )
        }
    }
#endif

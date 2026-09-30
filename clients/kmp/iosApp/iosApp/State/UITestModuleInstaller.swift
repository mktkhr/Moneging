#if DEBUG
    import Foundation
    import Observation
    import SharedLogic

    /// The stand-in for the module installer in UI tests
    /// (`-UITestModuleInstaller fake`): it downloads nothing and counts the
    /// requests it receives, which every screen shows as the element
    /// `module-install-requests`.
    @MainActor
    @Observable
    internal final class UITestModuleInstaller: NSObject, ReadingModuleInstaller {
        /// How many downloads were requested.
        internal private(set) var requestCount: Int = 0

        override internal init() {
            super.init()
        }

        /// Counts the request; downloads nothing.
        nonisolated internal func requestInstall(modules _: [ReadingModule]) {
            Task { @MainActor in
                self.requestCount += 1
            }
        }

        deinit {
            // Nothing to release.
        }
    }
#endif

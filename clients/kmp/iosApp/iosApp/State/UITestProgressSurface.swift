#if DEBUG
    import Observation

    /// The stand-in for the Live Activity in UI tests
    /// (`-UITestFakeProgressSurface YES`): home shows the element
    /// `progress-surface` exactly while it is shown.
    @MainActor
    @Observable
    internal final class UITestProgressSurface: ScanProgressSurface {
        /// Whether any scan is in flight.
        internal private(set) var isShown: Bool = false

        internal init() {
            // Hidden until a scan is in flight.
        }

        /// Shows while `progress` is given, hides at once when it is not.
        internal func show(progress: ScanActivityAttributes.ContentState?) {
            self.isShown = progress != nil
        }

        deinit {
            // Nothing to release.
        }
    }
#endif

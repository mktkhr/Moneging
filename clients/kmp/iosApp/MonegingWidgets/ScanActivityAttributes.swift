import ActivityKit

/// The Live Activity of the scans in flight (`LiveActivity5.dc.html`): on
/// the lock screen and in the Dynamic Island while any scan of the ledger
/// is queued or running, ended as soon as none is.
///
/// Compiled into the app, which starts, updates and ends it, and into the
/// widget extension, which draws it.
internal struct ScanActivityAttributes: ActivityAttributes {
    /// How far the scans have come.
    internal struct ContentState: Codable, Hashable {
        /// Scans queued or running.
        internal var inFlight: Int
        /// Drafts waiting to be confirmed.
        internal var waiting: Int
        /// Scans of this run that have finished.
        internal var finished: Int
        /// Scans this run has.
        internal var total: Int
    }

    /// The name of the ledger the scans are of.
    internal var ledgerName: String
    /// The user's accent colour, `#RRGGBB`, in light mode.
    internal var accentLightHex: String
    /// The user's accent colour, `#RRGGBB`, in dark mode.
    internal var accentDarkHex: String
}

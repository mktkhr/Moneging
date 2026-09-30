/// Where the progress of the scans in flight is shown outside the app
/// (PRODUCT.md §3, Scan job): a Live Activity, or a stand-in in UI tests.
@MainActor
internal protocol ScanProgressSurface: AnyObject {
    /// Shows `progress` of the ledger `ledgerName`'s scans, or ends the
    /// surface at once when `progress` is `nil` (no scan in flight).
    func show(ledgerName: String, progress: ScanActivityAttributes.ContentState?)
}

/// Where the progress of the scans in flight is shown outside the app
/// (PRODUCT.md §3, Scan job), whatever ledger is in view: a Live Activity,
/// or a stand-in in UI tests.
@MainActor
internal protocol ScanProgressSurface: AnyObject {
    /// Shows `progress` of the scans in flight in every ledger, or ends
    /// the surface at once when `progress` is `nil` (no scan in flight).
    func show(progress: ScanActivityAttributes.ContentState?)
}

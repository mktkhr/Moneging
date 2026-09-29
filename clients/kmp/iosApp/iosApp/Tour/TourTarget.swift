/// A control the tour can spotlight.
internal enum TourTarget: Hashable {
    /// The header's ledger title.
    case ledgerTitle
    /// The floating record button.
    case recordButton
    /// The tab bar: the capsule of the tabs and the separate 検索 button.
    case tabBar
}

/// A push destination shared by every tab's `NavigationStack`.
///
/// Every case leads to a placeholder screen; this shell has no real
/// destinations yet.
internal enum Route: Hashable {
    /// The お知らせ placeholder screen, opened from the header's bell icon.
    case notifications
    /// A row from the 記録する sheet, pushed after the sheet is dismissed.
    case recordOption(RecordOption)
    /// The editor renaming the ledger with this `Ledger.id` (as text),
    /// opened from 設定.
    case renameLedger(String)
    /// The 設定 screen, opened from the header's account icon.
    case settings
    /// A row inside 設定, pushed on top of the settings screen.
    case settingsDetail(SettingsItem)
}

/// A push destination shared by every tab's `NavigationStack`.
///
/// Every case leads to a placeholder screen; this shell has no real
/// destinations yet.
internal enum Route: Hashable {
    /// The 家計簿を追加 placeholder screen, opened from the ledger menu.
    case addLedger
    /// The お知らせ placeholder screen, opened from the header's bell icon.
    case notifications
    /// A row from the 記録する sheet, pushed after the sheet is dismissed.
    case recordOption(RecordOption)
    /// The 設定 screen, opened from the header's account icon.
    case settings
    /// A row inside 設定, pushed on top of the settings screen.
    case settingsDetail(SettingsItem)
}

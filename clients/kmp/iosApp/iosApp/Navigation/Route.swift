/// A push destination shared by every tab's `NavigationStack`.
internal enum Route: Hashable {
    /// 分類 of the ledger in view, opened from 設定.
    case categories
    /// The お知らせ placeholder screen, opened from the header's bell icon.
    case notifications
    /// 読み取りの方法: the device's reading method, opened from 設定.
    case readingMethod
    /// 毎月の定期 of the ledger in view, opened from 設定.
    case recurringRules
    /// The editor renaming the ledger with this `Ledger.id` (as text),
    /// opened from 設定.
    case renameLedger(String)
    /// 要確認の記録: the needs-review records of the ledger in view, opened
    /// from their count on ホーム.
    case reviewRecords
    /// レシートの読み取り: the scans of the ledger in view, opened from the
    /// status band on ホーム.
    case scans
    /// The 設定 screen, opened from the header's account icon.
    case settings
    /// A row inside 設定, pushed on top of the settings screen.
    case settingsDetail(SettingsItem)
}

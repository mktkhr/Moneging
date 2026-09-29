/// A single row inside the 設定 screen, grouped as in the design mockup
/// (`scratchpad/design/project/Settings.dc.html`).
internal enum SettingsItem: CaseIterable, Hashable {
    case appearance
    case backup
    case categories
    case notificationsDevice
    case receiptScanning

    /// The row's Japanese label.
    internal var label: String {
        switch self {
        case .appearance:
            "見た目"

        case .backup:
            "バックアップ"

        case .categories:
            "カテゴリ"

        case .notificationsDevice:
            "通知"

        case .receiptScanning:
            "写真からの読み取り"
        }
    }

    /// A stable, ASCII identifier for UI testing.
    internal var identifier: String {
        switch self {
        case .appearance:
            "appearance"

        case .backup:
            "backup"

        case .categories:
            "categories"

        case .notificationsDevice:
            "notifications-device"

        case .receiptScanning:
            "receipt-scanning"
        }
    }
}

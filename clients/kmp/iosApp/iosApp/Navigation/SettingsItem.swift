/// A single row inside the 設定 screen, grouped as in the design mockup
/// (`scratchpad/design/project/Settings.dc.html`).
internal enum SettingsItem: CaseIterable, Hashable {
    case appearance
    case backup
    case notificationsDevice

    /// The row's Japanese label.
    internal var label: String {
        switch self {
        case .appearance:
            "見た目"

        case .backup:
            "バックアップ"

        case .notificationsDevice:
            "通知"
        }
    }

    /// A stable, ASCII identifier for UI testing.
    internal var identifier: String {
        switch self {
        case .appearance:
            "appearance"

        case .backup:
            "backup"

        case .notificationsDevice:
            "notifications-device"
        }
    }
}

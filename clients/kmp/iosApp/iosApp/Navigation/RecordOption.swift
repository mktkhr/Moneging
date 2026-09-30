/// A single row inside the 記録する sheet (`RecordMenu5.dc.html`).
///
/// Declared in alphabetical order (SwiftLint's `sorted_enum_cases`); the
/// sheet's own row order comes from `sheetOrder`, not from this
/// declaration order or `CaseIterable.allCases`.
internal enum RecordOption: CaseIterable, Hashable {
    case manual
    case photoPick
    case receiptScan

    /// Row order for the 記録する sheet: 手で入力する → レシートを撮る →
    /// 写真を選ぶ.
    internal static let sheetOrder: [Self] = [.manual, .receiptScan, .photoPick]

    /// The row's title.
    internal var title: String {
        switch self {
        case .manual:
            "手で入力する"

        case .photoPick:
            "写真を選ぶ"

        case .receiptScan:
            "レシートを撮る"
        }
    }

    /// The row's subtitle, describing what it does.
    internal var subtitle: String {
        switch self {
        case .manual:
            "金額と分類を入れて記録"

        case .photoPick:
            "写真ライブラリから何枚でも"

        case .receiptScan:
            "何枚でも続けて。1ページが1枚のレシート"
        }
    }

    /// The SF Symbol shown in the row's leading icon.
    internal var systemImage: String {
        switch self {
        case .manual:
            "pencil"

        case .photoPick:
            "photo.on.rectangle"

        case .receiptScan:
            "doc.viewfinder"
        }
    }

    /// Whether it reads receipts from photos, which works only while the
    /// user has it enabled (設定 → 写真からの読み取り).
    internal var readsPhotos: Bool {
        self != .manual
    }

    /// A stable, ASCII identifier for UI testing (`record-option-<identifier>`).
    internal var identifier: String {
        switch self {
        case .manual:
            "manual"

        case .photoPick:
            "library"

        case .receiptScan:
            "scan"
        }
    }

    /// Whether it can be used: reading from photos only while it is enabled.
    internal func isAvailable(isPhotoReadingEnabled: Bool) -> Bool {
        !self.readsPhotos || isPhotoReadingEnabled
    }
}

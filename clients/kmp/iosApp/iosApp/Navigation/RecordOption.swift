/// A single row inside the 記録する sheet (`RecordMenu.dc.html`).
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
            "撮ったレシートの写真から"

        case .receiptScan:
            "撮るだけで下書きに"
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

    /// Whether it can be used yet; the others are shown disabled, marked
    /// 準備中 (reading receipts comes with stage 5).
    internal var isAvailable: Bool {
        self == .manual
    }

    /// A stable, ASCII identifier for UI testing.
    internal var identifier: String {
        switch self {
        case .manual:
            "manual"

        case .photoPick:
            "photo-pick"

        case .receiptScan:
            "receipt-scan"
        }
    }
}

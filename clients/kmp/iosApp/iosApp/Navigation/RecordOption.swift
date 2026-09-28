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
            "金額・カテゴリ・日付を入れる"

        case .photoPick:
            "写真ライブラリのレシートを読み取る"

        case .receiptScan:
            "書類スキャナで撮影して読み取る"
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

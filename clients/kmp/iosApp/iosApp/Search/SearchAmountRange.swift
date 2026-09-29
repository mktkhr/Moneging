/// The amount ranges the search's 金額 chip offers.
internal enum SearchAmountRange: CaseIterable, Hashable {
    case any
    case fromOneThousand
    case fromTenThousand
    case fromThreeThousand
    case underOneThousand

    /// The order the chip's menu lists them in.
    internal static let menuOrder: [Self] = [
        .any, .underOneThousand, .fromOneThousand, .fromThreeThousand, .fromTenThousand,
    ]

    private static let oneThousand: Int64 = 1_000
    private static let threeThousand: Int64 = 3_000
    private static let tenThousand: Int64 = 10_000

    /// The chip's title.
    internal var title: String {
        switch self {
        case .any:
            "金額"

        case .fromOneThousand:
            "1,000〜2,999円"

        case .fromTenThousand:
            "10,000円以上"

        case .fromThreeThousand:
            "3,000〜9,999円"

        case .underOneThousand:
            "1,000円未満"
        }
    }

    /// The least amount, or `nil`.
    internal var minAmount: Int64? {
        switch self {
        case .any, .underOneThousand:
            nil

        case .fromOneThousand:
            Self.oneThousand

        case .fromTenThousand:
            Self.tenThousand

        case .fromThreeThousand:
            Self.threeThousand
        }
    }

    /// The greatest amount, or `nil`.
    internal var maxAmount: Int64? {
        switch self {
        case .any, .fromTenThousand:
            nil

        case .fromOneThousand:
            Self.threeThousand - 1

        case .fromThreeThousand:
            Self.tenThousand - 1

        case .underOneThousand:
            Self.oneThousand - 1
        }
    }
}

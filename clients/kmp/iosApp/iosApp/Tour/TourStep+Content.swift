import SharedLogic

extension TourStep {
    /// The step's name in its callout's accessibility identifier
    /// (`tour-step-<identifier>`).
    internal var identifier: String {
        self.name.lowercased().replacingOccurrences(of: "_", with: "-")
    }

    /// The callout's heading.
    internal var title: String {
        switch self {
        case .ledger:
            String(localized: "ようこそ。まず家計簿をつくりましょう")

        case .record:
            String(localized: "支出はここから記録します")

        case .photoReading:
            String(localized: "レシートを写真から読み取りますか？")

        case .tabs:
            String(localized: "記録はここで振り返れます")
        }
    }

    /// The callout's explanation.
    internal var message: String {
        switch self {
        case .ledger:
            String(localized: "名前はあとから変えられます。家計簿は目的ごとに増やせます。")

        case .record:
            String(localized: "手で入力する・レシートを撮る・写真を選ぶ、の3つから選べます。")

        case .photoReading:
            String(
                localized:
                    "オンにすると、レシートを撮るか写真を選ぶだけで下書きになります。読み取りはこの端末の中だけで行い、写真はどこにも送られません。あとから設定で変えられます。"
            )

        case .tabs:
            String(localized: "カレンダーは日ごとの支出、レポートは分類ごとの内訳と12か月の推移、予算は今月の残りを表示します。")
        }
    }

    /// The control the step spotlights.
    internal var target: TourTarget {
        switch self {
        case .ledger:
            .ledgerTitle

        case .photoReading, .record:
            .recordButton

        case .tabs:
            .tabBar
        }
    }
}

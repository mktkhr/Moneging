import SharedLogic

extension TourStep {
    /// The step's name in its callout's accessibility identifier
    /// (`tour-step-<identifier>`).
    internal var identifier: String {
        self.name.lowercased()
    }

    /// The callout's heading.
    internal var title: String {
        switch self {
        case .ledger:
            String(localized: "ようこそ。まず家計簿をつくりましょう")

        case .record:
            String(localized: "支出はここから記録します")

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

        case .tabs:
            String(localized: "カレンダーは日ごとの支出、レポートは分類ごとの内訳と12か月の推移、予算は今月の残りを表示します。")
        }
    }

    /// The control the step spotlights.
    internal var target: TourTarget {
        switch self {
        case .ledger:
            .ledgerTitle

        case .record:
            .recordButton

        case .tabs:
            .tabBar
        }
    }
}

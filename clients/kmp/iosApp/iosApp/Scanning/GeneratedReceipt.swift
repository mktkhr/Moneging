import FoundationModels

/// What Foundation Models structures a receipt's text into: the store, the
/// date, the total and the items, each with how sure the model is of it.
@Generable(description: "レシートから読み取った内容")
internal struct GeneratedReceipt {
    /// One item of the receipt.
    @Generable(description: "レシートの1品目")
    internal struct Item {
        /// Its name as printed.
        @Guide(description: "品名。レシートに印字されたとおり（先頭の商品コード・軽減税率の印は除く）")
        internal var name: String

        /// Its amount in whole yen.
        @Guide(description: "金額（円、整数）。値引き・オプションを反映した額")
        internal var amount: Int

        /// A default category's name, or empty for none.
        @Guide(
            description:
                "分類。食費・日用品・住居・水道光熱費・交通費・通信費・医療・教育・娯楽・交際費・衣服・その他 のどれか。分からなければ空"
        )
        internal var category: String

        /// How sure the model is of the item, 0 to 1.
        @Guide(description: "この品目の読み取りにどれだけ自信があるか（0〜1）")
        internal var confidence: Double
    }

    /// The store name.
    @Guide(description: "店名。よく知られたチェーンならその名前。レシートの最初の行にあることが多い")
    internal var store: String

    /// How sure the model is of the store name, 0 to 1.
    @Guide(description: "店名の読み取りにどれだけ自信があるか（0〜1）")
    internal var storeConfidence: Double

    /// The date, `yyyy-MM-dd`, or empty.
    @Guide(description: "日付。yyyy-MM-dd の形。分からなければ空")
    internal var date: String

    /// How sure the model is of the date, 0 to 1.
    @Guide(description: "日付の読み取りにどれだけ自信があるか（0〜1）")
    internal var dateConfidence: Double

    /// The total in whole yen, or 0 when none was read.
    @Guide(description: "合計（円、整数）。分からなければ 0")
    internal var total: Int

    /// How sure the model is of the total, 0 to 1.
    @Guide(description: "合計の読み取りにどれだけ自信があるか（0〜1）")
    internal var totalConfidence: Double

    /// The items, in the receipt's order: options, discounts and subtotals
    /// excluded, an added tax included.
    @Guide(
        description:
            "品目。レシートの順。小計・合計・お預り・お釣り・値引き・オプションの行は含めない。外税なら最後に「消費税」"
    )
    internal var items: [Item]
}

import SwiftUI

extension Theme {
    /// Tokens of recording money: the home list, the entry and rule sheets,
    /// 分類 and 毎月の定期, from the design's 記録（ステージ2） artboards
    /// (`Home2.dc.html`, `Entry2.dc.html` and the ones after them).
    internal enum Recording {
        /// The SF Symbol of each default category, in the default order
        /// (`Category.defaultIndex`): 食費 to その他.
        internal static let categorySymbols: [String] = [
            "fork.knife", "basket", "house", "bolt", "tram", "iphone",
            "cross.case", "book", "star", "gift", "tshirt", "ellipsis",
        ]
        /// The icon colour of each default category, in the default order.
        internal static let categoryForegrounds: [Color] = [
            Color(
                light: "#C4622D",
                dark: "#DCA181",
            ),
            Color(
                light: "#8A6A2F",
                dark: "#B9A682",
            ),
            Color(
                light: "#6B5BA8",
                dark: "#A69DCB",
            ),
            Color(
                light: "#B8860B",
                dark: "#D4B66D",
            ),
            Color(
                light: "#2F7A8C",
                dark: "#82AFBA",
            ),
            Color(
                light: "#3F6FB0",
                dark: "#8CA9D0",
            ),
            Color(
                light: "#B24B6E",
                dark: "#D193A8",
            ),
            Color(
                light: "#5A7A2F",
                dark: "#9CAF82",
            ),
            Color(
                light: "#C0392B",
                dark: "#D98880",
            ),
            Color(
                light: "#A0527A",
                dark: "#C697AF",
            ),
            Color(
                light: "#4A6B8A",
                dark: "#92A6B9",
            ),
            Color(
                light: "#6B625B",
                dark: "#A6A19D",
            ),
        ]
        /// The icon tile's colour of each default category, in the default order.
        internal static let categoryBackgrounds: [Color] = [
            Color(
                light: "#F6E3D6",
                dark: "#52301E",
            ),
            Color(
                light: "#F1E8D2",
                dark: "#40331E",
            ),
            Color(
                light: "#E6E1F3",
                dark: "#372E42",
            ),
            Color(
                light: "#F6ECCF",
                dark: "#4E3B13",
            ),
            Color(
                light: "#D9EDF1",
                dark: "#25383A",
            ),
            Color(
                light: "#DDE7F5",
                dark: "#2A3445",
            ),
            Color(
                light: "#F5DEE6",
                dark: "#4C2931",
            ),
            Color(
                light: "#E3EDD5",
                dark: "#32381E",
            ),
            Color(
                light: "#F6DDD9",
                dark: "#51241D",
            ),
            Color(
                light: "#F2E0EA",
                dark: "#472C35",
            ),
            Color(
                light: "#DFE7EF",
                dark: "#2D333A",
            ),
            Color(
                light: "#ECE7E1",
                dark: "#37302B",
            ),
        ]
        /// The SF Symbol of a category the ledger added.
        internal static let addedCategorySymbol: String = "tag"
        /// The icon colour of a category the ledger added.
        internal static let addedCategoryForeground: Color = Color(
            light: "#6B625B",
            dark: "#A6A19D",
        )
        /// The icon tile's colour of a category the ledger added.
        internal static let addedCategoryBackground: Color = Color(
            light: "#ECE7E1",
            dark: "#37302B",
        )
        /// The SF Symbol of an income.
        internal static let incomeSymbol: String = "arrow.up"
        /// The icon tile's colour of an income.
        internal static let incomeBackground: Color = Color(
            light: "#DCEDE7",
            dark: "#25342C",
        )
        /// The 定期 mark's background.
        internal static let badgeBackground: Color = Color(
            light: "#ECE7E1",
            dark: "#37302B",
        )
        /// A destructive action's text (この記録を削除, アーカイブする…).
        internal static let destructive: Color = Color(
            light: "#B42318",
            dark: "#F97066",
        )

        /// The side of a category's icon tile at the default text size.
        internal static let iconSize: CGFloat = 40
        /// How far a category's icon tile grows with the text size.
        internal static let iconMaximumScale: CGFloat = 2
        /// The corner radius of a category's icon tile.
        internal static let iconRadius: CGFloat = 12
        /// The corner radius of a category tile in the entry sheet's grid.
        internal static let tileRadius: CGFloat = 14
        /// The width of a chosen category tile's border.
        internal static let tileBorderWidth: CGFloat = 2
        /// The least height of a category tile.
        internal static let tileMinHeight: CGFloat = 72
        /// Columns of the category grid at ordinary text sizes.
        internal static let gridColumns: Int = 4
        /// Columns of the category grid at accessibility text sizes.
        internal static let accessibilityGridColumns: Int = 2
        /// The size of the entry sheet's amount at the default text size.
        internal static let amountFontSize: CGFloat = 44
        /// The size of the home screen's totals at the default text size.
        internal static let totalFontSize: CGFloat = 20
        /// The first day of a month a rule may fall on.
        internal static let firstDay: Int = 1
        /// The last day of a month a rule may fall on.
        internal static let lastDay: Int = 31
        /// How far a total may shrink to stay on one line.
        internal static let totalMinimumScale: CGFloat = 0.6
        /// The corner radius of the 定期 mark and the search chips.
        internal static let badgeRadius: CGFloat = 9
    }
}

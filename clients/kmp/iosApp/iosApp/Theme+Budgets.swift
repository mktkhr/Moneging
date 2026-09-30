import SwiftUI

extension Theme {
    /// Tokens of the budget view and its sheets, from the design's ステージ4
    /// artboards (`Budget4.dc.html`, `BudgetEdit4.dc.html`,
    /// `MonthClose4.dc.html`).
    internal enum Budgets {
        /// An overspent budget's amount and bar (`1,500円オーバー`).
        internal static let over: Color = Color(
            light: "#B8432F",
            dark: "#E08A7A",
        )
        /// A budget bar's empty track.
        internal static let barTrack: Color = Color(
            light: "#ECE7E1",
            dark: "#37302B",
        )
        /// The height of a budget bar.
        internal static let barHeight: CGFloat = 8
        /// The corner radius of a budget bar.
        internal static let barRadius: CGFloat = 4
        /// The whole month's remaining at the default text size.
        internal static let wholeAmountFontSize: CGFloat = 30
        /// The budget sheet's amount at the default text size.
        internal static let amountFontSize: CGFloat = 44
        /// How opaque the offer to close a month's border is.
        internal static let offerBorderOpacity: CGFloat = 0.25
        /// The corner radius of the offer to close a month.
        internal static let offerRadius: CGFloat = 18
        /// Where a row's divider starts: past the icon.
        internal static let dividerInset: CGFloat = 64
        /// The most lines a category's name wraps to in a row.
        internal static let nameLineLimit: Int = 2
        /// The height of the button that closes a month.
        internal static let confirmHeight: CGFloat = 50
    }
}

import SwiftUI

extension Theme {
    /// Tokens of the calendar and the report, from the design's ステージ3
    /// artboards (`Calendar3.dc.html`, `Report3.dc.html`).
    internal enum Reports {
        // MARK: - Calendar

        /// A Sunday's day number and weekday name.
        internal static let sunday: Color = Color(
            light: "#B8432F",
            dark: "#E08A7A",
        )
        /// A Saturday's day number and weekday name.
        internal static let saturday: Color = Color(
            light: "#3F6FB0",
            dark: "#8CA9D0",
        )
        /// A future day's number.
        internal static let futureDay: Color = Color(
            light: "#9A918A",
            dark: "#7A726B",
        )
        /// The height of a day's cell at the default text size.
        internal static let dayCellHeight: CGFloat = 64
        /// The corner radius of a day's cell.
        internal static let dayCellRadius: CGFloat = 12
        /// The width of today's outline.
        internal static let todayBorderWidth: CGFloat = 1.5
        /// How far a day's amount may shrink to be shown in full.
        internal static let dayAmountMinimumScale: CGFloat = 0.5
        /// The side of the NMD badge in a day's cell.
        internal static let badgeSize: CGFloat = 26
        /// The side of the NMD badge in the legend.
        internal static let legendBadgeSize: CGFloat = 16

        // MARK: - NMD badge (にっこり硬貨)

        /// The coin's face.
        internal static let coinFill: Color = Color(
            light: "#F2C94C",
            dark: "#F2C94C",
        )
        /// The coin's rim.
        internal static let coinRim: Color = Color(
            light: "#C99A1E",
            dark: "#C99A1E",
        )
        /// The coin's inner ring.
        internal static let coinInnerRing: Color = Color(
            light: "#E0B23A",
            dark: "#E0B23A",
        )
        /// The coin's eyes and smile.
        internal static let coinFace: Color = Color(
            light: "#5A3E0A",
            dark: "#5A3E0A",
        )

        // MARK: - Report

        /// The ring's diameter at the default text size.
        internal static let ringDiameter: CGFloat = 140
        /// The ring's width.
        internal static let ringLineWidth: CGFloat = 18
        /// The gap between two arcs of the ring, as a fraction of the circle.
        internal static let ringGap: CGFloat = 0.006
        /// Where the ring starts, in degrees from the right: at the top.
        internal static let ringStartDegrees: Double = -90
        /// How far the ring's inside is from its frame: half its width.
        internal static let ringInset: CGFloat = 9
        /// The ring's empty track.
        internal static let ringTrack: Color = Color(
            light: "#ECE7E1",
            dark: "#37302B",
        )
        /// The side of a category's colour swatch in the share's list.
        internal static let swatchSize: CGFloat = 10
        /// The corner radius of a category's colour swatch.
        internal static let swatchRadius: CGFloat = 3
        /// The least height of a row of the share's list.
        internal static let shareRowMinHeight: CGFloat = 30
        /// The lines a category's name may take in the share's list before it
        /// ends in `…`.
        internal static let shareNameLineLimit: Int = 2
        /// The width of a percentage in the share's list, so the amounts align.
        internal static let percentWidth: CGFloat = 40
        /// The width of a trend's bar.
        internal static let barWidth: CGFloat = 14
        /// The height of the tallest bar.
        internal static let barMaxHeight: CGFloat = 96
        /// The corner radius of a trend's bar.
        internal static let barRadius: CGFloat = 5
        /// A month's bar other than the month in view's.
        internal static let bar: Color = Color(
            light: "#D9CFC6",
            dark: "#4A423C",
        )
    }

    /// The NMD badge's drawing (にっこり硬貨), in the units of a 32-unit
    /// square.
    internal enum NmdCoin {
        /// The side of the square the coin is drawn in.
        internal static let canvas: CGFloat = 32
        /// The coin's centre, on both axes.
        internal static let center: CGFloat = 16
        /// The coin's radius.
        internal static let radius: CGFloat = 13
        /// The rim's width.
        internal static let rimWidth: CGFloat = 2
        /// The inner ring's radius.
        internal static let innerRadius: CGFloat = 9.5
        /// The inner ring's width.
        internal static let innerWidth: CGFloat = 1.2
        /// Each eye's radius.
        internal static let eyeRadius: CGFloat = 1.4
        /// The left eye's centre, across.
        internal static let leftEyeX: CGFloat = 12.5
        /// The right eye's centre, across.
        internal static let rightEyeX: CGFloat = 19.5
        /// The eyes' centre, down.
        internal static let eyeY: CGFloat = 14
        /// Where the smile starts, across.
        internal static let smileStartX: CGFloat = 11.5
        /// Where the smile ends, across.
        internal static let smileEndX: CGFloat = 20.5
        /// Where the smile starts and ends, down.
        internal static let smileY: CGFloat = 18.2
        /// The smile's control point, down (across, it is the centre).
        internal static let smileControlY: CGFloat = 22.2
        /// The smile's width.
        internal static let smileWidth: CGFloat = 1.6
    }
}

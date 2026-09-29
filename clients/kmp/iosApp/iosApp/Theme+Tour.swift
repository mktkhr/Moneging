import SwiftUI

extension Theme {
    /// Tokens of the onboarding tour's coach marks (`TourOverlay`), from the
    /// design's tour artboards (`OnbLedger.dc.html` and the steps after it):
    /// the app dimmed except a spotlight around one control, and a callout
    /// with an arrow toward it.
    internal enum Tour {
        /// The dim laid over the app around the spotlight (the artboards'
        /// `rgba(24,19,16,0.64)`), the same in light and dark.
        internal static let dim: Color = Color(light: "#181310A3", dark: "#000000B8")
        /// The ring drawn around the spotlight (`rgba(255,255,255,0.9)`).
        internal static let spotlightRing: Color = Color(light: "#FFFFFFE6", dark: "#FFFFFFB3")
        /// The callout's surface: white on the dimmed app, the style's
        /// surface in dark mode.
        internal static let calloutSurface: Color = Color(light: "#FFFFFF", dark: "#2D2520")
        /// The callout's drop shadow (`0 16px 40px rgba(0,0,0,0.28)`).
        internal static let calloutShadow: Color = Color(light: "#00000047", dark: "#00000080")
        /// An inactive page dot (`rgba(31,27,24,0.18)`).
        internal static let inactiveDot: Color = Color(light: "#1F1B182E", dark: "#FFFFFF33")

        /// How far the spotlight extends around its control.
        internal static let spotlightPadding: CGFloat = 6
        /// The spotlight's corner radius.
        internal static let spotlightRadius: CGFloat = 16
        /// The width of the spotlight's ring.
        internal static let spotlightRingWidth: CGFloat = 2
        /// The gap between the spotlight and the callout's arrow.
        internal static let calloutGap: CGFloat = 14
        /// The callout's corner radius.
        internal static let calloutRadius: CGFloat = 20
        /// The callout's inner padding.
        internal static let calloutPadding: CGFloat = 18
        /// The blur radius of the callout's shadow.
        internal static let calloutShadowRadius: CGFloat = 20
        /// The vertical offset of the callout's shadow.
        internal static let calloutShadowY: CGFloat = 8
        /// The side of the square that, turned 45°, is the callout's arrow.
        internal static let arrowSize: CGFloat = 18
        /// The arrow's corner radius.
        internal static let arrowRadius: CGFloat = 3
        /// How far the arrow is kept from the callout's corners.
        internal static let arrowInset: CGFloat = 32
        /// The arrow's turn, in degrees, making the square a diamond.
        internal static let arrowRotationDegrees: Double = 45
        /// The height (and inactive width) of a page dot.
        internal static let dotSize: CGFloat = 6
        /// The width of the current step's page dot.
        internal static let activeDotWidth: CGFloat = 18
        /// The gap between page dots.
        internal static let dotSpacing: CGFloat = 5
        /// The corner radius of the name field in the callout.
        internal static let fieldRadius: CGFloat = 12
        /// The width of the name field's border.
        internal static let fieldBorderWidth: CGFloat = 1.5
        /// The tab bar's height below the top of its area, for its spotlight:
        /// the Liquid Glass bar's capsule, measured on the simulator.
        internal static let tabBarHeight: CGFloat = 62
        /// The fraction of the screen's height above which a spotlight gets
        /// its callout below it (and below which, above it).
        internal static let calloutBelowThreshold: CGFloat = 0.5
    }
}

extension Theme {
    /// The opacity of a filled button's fill while it is disabled.
    internal static let disabledOpacity: CGFloat = 0.4
    /// The opacity of a custom-styled button while it is pressed.
    internal static let pressedOpacity: CGFloat = 0.7
}

extension Theme {
    /// The share of a name field's width, at its trailing edge, that its
    /// text never covers (`EndCaretTextField`).
    internal static let nameFieldTrailingInsetFraction: CGFloat = 0.12
}

import SwiftUI

/// Shared visual constants for the placeholder UI shell, matching the
/// terracotta-and-warm-paper palette used in the design mockups
/// (`scratchpad/design/project/OptionB.dc.html` and friends).
internal enum Theme {
    private static let accentRed: Double = 0.706
    private static let accentGreen: Double = 0.325
    private static let accentBlue: Double = 0.184
    private static let backgroundRed: Double = 0.969
    private static let backgroundGreen: Double = 0.953
    private static let backgroundBlue: Double = 0.933

    /// Primary accent color: buttons, checkmarks, the active tab.
    internal static let accent: Color = Color(
        red: Self.accentRed,
        green: Self.accentGreen,
        blue: Self.accentBlue,
    )

    /// Screen background color.
    internal static let background: Color = Color(
        red: Self.backgroundRed,
        green: Self.backgroundGreen,
        blue: Self.backgroundBlue,
    )

    /// Minimum tappable dimension for icon-only controls (HIG minimum).
    internal static let minimumTapTarget: CGFloat = 44

    /// Diameter of the floating record button.
    internal static let recordButtonDiameter: CGFloat = 62
}

import SharedLogic
import SwiftUI
import UIKit

/// Semantic design tokens for the iOS shell.
///
/// Values come from the shared Kotlin design-token data
/// (`sharedLogic`'s `theme` package: `ThemeTokens.kt`, `ThemeColorMath.kt`,
/// `ResolvedTheme.kt`), itself ported verbatim from takamai's reference
/// theme (`takamai/frontend/src/shared/theme/tokens.ts`,
/// `createAppTheme.ts`, `color.ts`, read 2026-09-28). Both `light` and
/// `dark` are resolved once and combined into each dynamic `Color`, so the
/// shell tracks the device's own appearance automatically - the
/// `DefaultAppearance` this shell has until 見た目 settings exist
/// (takamai backend `backend/internal/domain/appearance.go`): style Soft,
/// colour テラコッタ, brightness system.
///
/// Every screen/component reads a role from here rather than a literal
/// colour, so switching the chosen style/colour (once 見た目 settings
/// exist) only ever means changing `style`/`color` below.
internal enum Theme {
    private static let style: ThemeStyle = ThemeTokensKt.defaultStyle
    private static let color: ThemeColor = ThemeTokensKt.defaultColor

    private static let light: ResolvedTheme = ResolvedThemeKt.resolveTheme(
        style: Self.style,
        color: Self.color,
        scheme: .light,
    )
    private static let dark: ResolvedTheme = ResolvedThemeKt.resolveTheme(
        style: Self.style,
        color: Self.color,
        scheme: .dark,
    )

    /// Screen background.
    internal static let background: Color = Color(
        light: Self.light.background,
        dark: Self.dark.background,
    )
    /// A card/row's own surface, distinct from the screen background.
    internal static let surface: Color = Color(
        light: Self.light.surface,
        dark: Self.dark.surface,
    )
    /// Primary text.
    internal static let text: Color = Color(
        light: Self.light.text,
        dark: Self.dark.text,
    )
    /// Secondary/muted text, and the toolbar's own icons (お知らせ/アカウント).
    internal static let mutedText: Color = Color(
        light: Self.light.mutedText,
        dark: Self.dark.mutedText,
    )
    /// Hairline dividers and card borders.
    internal static let line: Color = Color(
        light: Self.light.line,
        dark: Self.dark.line,
    )
    /// Primary accent color: buttons, the selected tab, checkmarks.
    internal static let accent: Color = Color(
        light: Self.light.accent,
        dark: Self.dark.accent,
    )
    /// The colour scheme's own fixed text/icon colour drawn on top of `accent`.
    internal static let onAccent: Color = Color(
        light: Self.light.onAccent,
        dark: Self.dark.onAccent,
    )

    // `accentTint` (a selected pill's background) and `glassSurface` (a
    // translucent floating-chrome surface) are not mapped here: nothing in
    // this shell paints with them yet, and an unused `Color` fails
    // `swiftlint-analyze`'s `unused_declaration`. Both stay available as
    // data - `ResolvedTheme.accentTint`/`.glassSurface`
    // (`sharedLogic`'s `theme` package) - for whenever a consumer needs
    // them; mapping either here is then a one-line addition.

    /// A floating element's own drop shadow colour: the current style's
    /// `shadow` token (`StyleSchemeTokens.shadow` in `ThemeTokens.kt`,
    /// parsed by `parseCssBoxShadow` in `ThemeColorMath.kt`), tracking
    /// light/dark like every other colour here.
    internal static let shadowColor: Color = Color(
        light: Self.light.shadowColor,
        dark: Self.dark.shadowColor,
    )

    // MARK: - Shape

    // Ported from the current style's own tokens
    // (`ThemeTokensKt.defaultStyleTokens`, `sharedLogic`'s `ThemeTokens.kt`,
    // itself ported from takamai's `tokens.ts` `StyleTokens`) - see
    // `Theme`'s own doc comment for the source and read date.

    /// The style's base corner radius: a card/row's own rounding (takamai
    /// `StyleTokens.radius`; Soft = 22).
    internal static let radius: CGFloat = CGFloat(ThemeTokensKt.defaultStyleTokens.radius)

    // `btnRadius` (takamai `StyleTokens.btnRadius`; a rounded-rect button's
    // own corner radius) is not mapped here: nothing in this shell paints a
    // rounded-rect button yet (the floating 記録する button is a `Circle`;
    // every other button is plain/list-styled), and an unused `CGFloat`
    // fails `swiftlint-analyze`'s `unused_declaration` - see the same note
    // above for `accentTint`/`glassSurface`. `ThemeTokensKt.defaultStyleTokens.btnRadius`
    // stays available as data for whenever a consumer needs it. The same
    // holds for `chipRadius` (takamai `StyleTokens.chipRadius`; a text
    // chip's own pill rounding): the record sheet's icon tiles are rounded
    // squares (`iconTileRadius` below), not chips.
    /// This style's own drop shadow's blur radius (takamai
    /// `StyleSchemeTokens.shadow`; 0 when the style has none).
    internal static let shadowBlurRadius: CGFloat = CGFloat(Self.light.shadowBlurRadius)
    /// This style's own drop shadow's vertical offset (takamai
    /// `StyleSchemeTokens.shadow`; 0 when the style has none).
    internal static let shadowOffsetY: CGFloat = CGFloat(Self.light.shadowOffsetY)

    // The spacing scale lives in `Theme.Spacing` (`Theme+Spacing.swift`).

    // MARK: - Shape (component)

    /// Corner radius of a small filled icon tile.
    ///
    /// The 記録する rows' leading icon square (`RecordMenu.dc.html`'s 12px):
    /// a rounded square, not a pill - the style's `chipRadius` (999 for
    /// Soft) is for text chips.
    internal static let iconTileRadius: CGFloat = 12

    // MARK: - Sizes

    /// Minimum tappable dimension for any control (HIG minimum).
    internal static let minimumTapTarget: CGFloat = 44

    /// Diameter of the floating record button.
    internal static let recordButtonDiameter: CGFloat = 62

    /// Side length of an icon tile at the default text size; scaled with
    /// Dynamic Type by its consumer (`@ScaledMetric`).
    internal static let iconTileSize: CGFloat = 40

    /// Line width of a `PlaceholderCard` card's dashed border.
    internal static let dashedBorderLineWidth: CGFloat = 1.5
    /// Length of each dash of a `PlaceholderCard` card's dashed border.
    internal static let dashedBorderDashLength: CGFloat = 6
    /// Length of each gap between a `PlaceholderCard` card's border dashes.
    internal static let dashedBorderGapLength: CGFloat = 4

    // The tab bar's unselected items keep the system look on purpose: as of
    // iOS 26 their colour cannot be customised (Liquid Glass tab bars ignore
    // `unselectedItemTintColor` and `UITabBarAppearance`; Apple DTS,
    // https://developer.apple.com/forums/thread/818449). Only the selected
    // item is tinted, via `.tint(Theme.accent)` on the `TabView`.
}

extension Color {
    /// Builds a colour that tracks the trait collection automatically.
    ///
    /// Resolves to `lightHex` in light mode and `darkHex` in dark mode -
    /// the supported dynamic-colour pattern
    /// (`UIColor.init(dynamicProvider:)`).
    ///
    /// - Parameters:
    ///   - lightHex: "#RRGGBB" or "#RRGGBBAA", used in light mode.
    ///   - darkHex: "#RRGGBB" or "#RRGGBBAA", used in dark mode.
    internal init(light lightHex: String, dark darkHex: String) {
        self = Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
            },
        )
    }
}

extension UIColor {
    /// "#RRGGBB" is 6 hex digits; "#RRGGBBAA" (with an alpha channel) is 8.
    internal static let hexDigitCountWithAlpha: Int = 8
    /// Bits one colour or alpha channel's own two hex digits occupy.
    internal static let channelBitWidth: UInt64 = 8
    /// A colour channel's own bitmask (0-255, its full 8-bit range).
    internal static let channelMask: UInt64 = 0xFF
    /// A colour channel's own maximum value, as a `CGFloat` divisor.
    internal static let channelMax: CGFloat = 255

    /// Parses a "#RRGGBB" or "#RRGGBBAA" string into a colour.
    ///
    /// Falls back to opaque black for a malformed string, since every
    /// token this shell feeds it is a compile-time literal (see
    /// `ThemeTokens.kt`) — a parse failure here would be a programmer
    /// error, not user-facing data.
    internal convenience init(hex: String) {
        var digits: String = hex
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }

        var value: UInt64 = 0
        Scanner(string: digits).scanHexInt64(&value)

        let hasAlpha: Bool = digits.count == Self.hexDigitCountWithAlpha
        let alpha: CGFloat = hasAlpha ? Self.channel(value, shift: 0) : 1
        let blueShift: UInt64 = hasAlpha ? Self.channelBitWidth : 0
        let greenShift: UInt64 = blueShift + Self.channelBitWidth
        let redShift: UInt64 = greenShift + Self.channelBitWidth
        let blue: CGFloat = Self.channel(value, shift: blueShift)
        let green: CGFloat = Self.channel(value, shift: greenShift)
        let red: CGFloat = Self.channel(value, shift: redShift)

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Reads one 0-255 channel out of `value`, `shift` bits in, as a 0-1 `CGFloat`.
    internal static func channel(_ value: UInt64, shift: UInt64) -> CGFloat {
        CGFloat((value >> shift) & Self.channelMask) / Self.channelMax
    }
}

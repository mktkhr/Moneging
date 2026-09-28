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
    /// Secondary/muted text, and the tab bar's/toolbar's unselected icons.
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
    /// A button's own corner radius (takamai `StyleTokens.btnRadius`; Soft
    /// = 999, i.e. a full pill).
    internal static let btnRadius: CGFloat = CGFloat(ThemeTokensKt.defaultStyleTokens.btnRadius)
    /// A chip's own corner radius (takamai `StyleTokens.chipRadius`; Soft =
    /// 999, i.e. a full pill).
    internal static let chipRadius: CGFloat = CGFloat(ThemeTokensKt.defaultStyleTokens.chipRadius)
    /// This style's own drop shadow's blur radius (takamai
    /// `StyleSchemeTokens.shadow`; 0 when the style has none).
    internal static let shadowBlurRadius: CGFloat = CGFloat(Self.light.shadowBlurRadius)
    /// This style's own drop shadow's vertical offset (takamai
    /// `StyleSchemeTokens.shadow`; 0 when the style has none).
    internal static let shadowOffsetY: CGFloat = CGFloat(Self.light.shadowOffsetY)

    // MARK: - Spacing scale

    // takamai's own `tokens.ts` has no generic spacing scale (only the
    // shape tokens above); this shell's own paddings/spacings/insets each
    // come from one of these steps, so there is exactly one place that
    // decides "how much space" anywhere in the shell.

    /// 2pt.
    internal static let spacing2: CGFloat = 2
    /// 4pt.
    internal static let spacing4: CGFloat = 4
    /// 6pt.
    internal static let spacing6: CGFloat = 6
    /// 8pt.
    internal static let spacing8: CGFloat = 8
    /// 10pt.
    internal static let spacing10: CGFloat = 10
    /// 12pt.
    internal static let spacing12: CGFloat = 12
    /// 14pt.
    internal static let spacing14: CGFloat = 14
    /// 16pt.
    internal static let spacing16: CGFloat = 16
    /// 20pt.
    internal static let spacing20: CGFloat = 20

    // MARK: - Sizes

    /// Minimum tappable dimension for icon-only controls (HIG minimum).
    internal static let minimumTapTarget: CGFloat = 44

    /// Diameter of the floating record button.
    internal static let recordButtonDiameter: CGFloat = 62

    /// Side length of a `RecordOptionRow` row's leading icon square.
    internal static let iconSize: CGFloat = 40

    /// Minimum height of a `RecordOptionRow`.
    internal static let recordOptionRowMinHeight: CGFloat = 64

    /// Minimum height of ホーム's "読み取り中・確認待ち" placeholder card.
    internal static let pendingCardMinHeight: CGFloat = 64

    /// Minimum height of ホーム's "今月の残り予算" placeholder card.
    internal static let budgetCardMinHeight: CGFloat = 132

    /// Line width of a `PlaceholderCard` card's dashed border.
    internal static let dashedBorderLineWidth: CGFloat = 1.5

    // MARK: - Debug marker

    /// Font size `TabRootLifecycleMarker` renders at: small enough to be
    /// visually negligible, never zero (SwiftUI clamps/ignores a
    /// non-positive font size, which would stop it rendering - and being
    /// read - at all).
    internal static let debugMarkerFontSize: CGFloat = 1
    /// Opacity `TabRootLifecycleMarker` renders at: near-zero, not zero, so
    /// it stays in the accessibility tree/hit-testable by XCUITest while
    /// staying visually negligible.
    internal static let debugMarkerOpacity: Double = 0.01

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

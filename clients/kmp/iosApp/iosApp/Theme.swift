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

    /// Minimum tappable dimension for icon-only controls (HIG minimum).
    internal static let minimumTapTarget: CGFloat = 44

    /// Diameter of the floating record button.
    internal static let recordButtonDiameter: CGFloat = 62

    /// Applies `mutedText` as the tab bar's unselected item colour.
    ///
    /// Covers icons and labels; `.tint(Theme.accent)` on the `TabView`
    /// already covers the selected item. `UITabBarAppearance`/
    /// `unselectedItemTintColor` is the supported way to set this: no
    /// public SwiftUI modifier configures a `TabView`'s unselected tint
    /// directly. Called once, at app launch (`MonegingApp.init`).
    internal static func applyTabBarAppearance() {
        UITabBar.appearance().unselectedItemTintColor = UIColor(Self.mutedText)
    }
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

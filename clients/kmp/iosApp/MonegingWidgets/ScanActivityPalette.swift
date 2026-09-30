import SwiftUI
import UIKit

/// The colours of the Live Activity: the user's accent, handed over by the
/// app as `#RRGGBB` (the extension cannot read the app's theme), in light
/// and dark.
internal enum ScanActivityPalette {
    private static let hexRadix: Int = 16
    private static let hexDigits: Int = 6
    private static let redShift: UInt64 = 16
    private static let greenShift: UInt64 = 8
    private static let channelMask: UInt64 = 0xFF
    private static let channelMax: CGFloat = 255
    private static let opaque: CGFloat = 1

    /// The accent of `attributes`, tracking light and dark.
    internal static func accent(of attributes: ScanActivityAttributes) -> Color {
        Color(
            UIColor { traits in
                Self.color(
                    hex: traits.userInterfaceStyle == .dark
                        ? attributes.accentDarkHex : attributes.accentLightHex,
                )
            },
        )
    }

    // `#RRGGBB` as a colour; opaque grey when malformed.
    private static func color(hex: String) -> UIColor {
        let digits: String = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard let value = UInt64(digits.prefix(Self.hexDigits), radix: Self.hexRadix) else {
            return .gray
        }
        return UIColor(
            red: Self.channel(value >> Self.redShift),
            green: Self.channel(value >> Self.greenShift),
            blue: Self.channel(value),
            alpha: Self.opaque,
        )
    }

    // The lowest channel of `value`, from 0 to 1.
    private static func channel(_ value: UInt64) -> CGFloat {
        CGFloat(value & Self.channelMask) / Self.channelMax
    }
}

import SwiftUI

/// The tab bar's own current height, as measured from inside a main tab's
/// content (its bottom safe-area inset there is exactly the tab bar's
/// reserved space) - not a constant, since it varies with the tab bar's own
/// state (e.g. iOS 26 Liquid Glass's collapsed/expanded appearance),
/// Dynamic Type and device.
///
/// `MainTabScreen` emits it; `RootView` reads it to position the floating
/// 記録する button just above the tab bar, deriving its inset instead of
/// hard-coding it.
internal struct TabBarBottomInsetPreferenceKey: PreferenceKey {
    internal static var defaultValue: CGFloat = 0

    internal static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

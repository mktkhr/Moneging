import SwiftUI

/// A debug-only, invisible test hook exposing a tab root's creation count.
///
/// Adds nothing to the screen: in `DEBUG` builds it marks the tab root's
/// own existing container as an accessibility container
/// (`.accessibilityElement(children: .contain)`, so every child stays
/// individually accessible) identified as `<screenID>-tab-root`, whose
/// `accessibilityValue` is the creation count. XCUITest reads that value to
/// assert the count stays at 1 across tab switches. Release builds get the
/// content unchanged.
internal struct TabRootLifecycleHook: ViewModifier {
    internal let screenID: String
    internal let creationCount: Int

    internal func body(content: Content) -> some View {
        #if DEBUG
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("\(self.screenID)-tab-root")
                .accessibilityValue(String(self.creationCount))
        #else
            content
        #endif
    }
}

extension View {
    /// Exposes a tab root's creation count to UI tests, in debug builds only.
    ///
    /// See `TabRootLifecycleHook`.
    ///
    /// - Parameters:
    ///   - screenID: the tab root's own screen id (e.g. "home").
    ///   - creationCount: how many times that tab root's state was created.
    /// - Returns: this view, carrying the debug-only test hook.
    internal func tabRootLifecycleHook(screenID: String, creationCount: Int) -> some View {
        self.modifier(TabRootLifecycleHook(screenID: screenID, creationCount: creationCount))
    }
}

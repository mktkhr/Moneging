import SwiftUI

/// A near-invisible, debug-only marker exposing a tab root's creation count.
///
/// XCUITest reads it through an accessibility identifier/value to assert
/// the count stays at 1 across tab switches. Not rendered in release
/// builds.
internal struct TabRootLifecycleMarker: View {
    internal let screenID: String
    internal let creationCount: Int

    internal var body: some View {
        #if DEBUG
            Text(String(self.creationCount))
                .font(.system(size: Theme.debugMarkerFontSize))
                .opacity(Theme.debugMarkerOpacity)
                .accessibilityIdentifier("\(self.screenID)-creation-count")
                .accessibilityValue(String(self.creationCount))
        #else
            EmptyView()
        #endif
    }
}

import SwiftUI

/// A near-invisible, debug-only marker exposing a `measureHeight(into:)`
/// result.
///
/// XCUITest reads it through an accessibility identifier/value to verify a
/// `fittedSheet(height:)` detent against the measured height it was given
/// - the same pattern `TabRootLifecycleMarker` uses for creation counts.
/// Not rendered in release builds.
internal struct MeasuredHeightMarker: View {
    private static let fontSize: CGFloat = 1
    private static let opacity: Double = 0.01

    internal let screenID: String
    internal let height: CGFloat?

    private var text: String {
        self.height.map { "\($0)" } ?? ""
    }

    internal var body: some View {
        #if DEBUG
            Text(self.text)
                .font(.system(size: Self.fontSize))
                .opacity(Self.opacity)
                .accessibilityIdentifier("\(self.screenID)-measured-height")
                .accessibilityValue(self.text)
        #else
            EmptyView()
        #endif
    }
}

import SwiftUI

/// Sizes the sheet presenting this content to exactly the content's own
/// height, with no extra empty space left below it.
///
/// Three official SwiftUI APIs, applied in this order to the sheet's own
/// (presented) content:
///
/// 1. `fixedSize(horizontal:vertical:)`
///    (https://developer.apple.com/documentation/swiftui/view/fixedsize(horizontal:vertical:))
///    makes the content lay out at its ideal height, whatever height the
///    sheet proposes - so the measurement never depends on the detent it
///    produces.
/// 2. `onGeometryChange(for:of:action:)`
///    (https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))
///    reads that height.
/// 3. `presentationDetents(_:)`
///    (https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))
///    with `PresentationDetent.height(_:)`
///    (https://developer.apple.com/documentation/swiftui/presentationdetent/height(_:))
///    makes it the sheet's only detent.
///
/// No hard-coded height anywhere: the detent tracks whatever the content
/// actually measures, and follows it if the content's height changes
/// (e.g. Dynamic Type).
internal struct FittedSheetModifier: ViewModifier {
    @State private var height: CGFloat?

    internal func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                self.height = newHeight
            }
            .presentationDetents(self.height.map { [.height($0)] } ?? [.medium])
    }
}

extension View {
    /// Sizes the sheet presenting this view to this view's own height.
    ///
    /// Apply to the root of a `.sheet`'s content. See
    /// `FittedSheetModifier`'s doc comment for how.
    internal func fittedSheet() -> some View {
        self.modifier(FittedSheetModifier())
    }
}

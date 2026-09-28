import SwiftUI

/// Sizes the sheet presenting this content to exactly the content's own
/// height, with no extra empty space left below it - unless the content is
/// taller than the sheet can actually be, in which case the sheet clamps to
/// that available height and its content scrolls instead of clipping.
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
/// actually measures, and follows it if the content's height changes (e.g.
/// Dynamic Type) - and at the largest accessibility text sizes, where the
/// content's own ideal height can exceed what the sheet is ever allowed to
/// be, the detent clamps to `maxHeight` and the content scrolls
/// (`ScrollView` + `.scrollBounceBehavior(.basedOnSize)`) rather than being
/// clipped.
internal struct FittedSheetModifier: ViewModifier {
    @State private var idealHeight: CGFloat?

    /// The most height the sheet is ever allowed to occupy, measured by the
    /// presenting view's `GeometryReader` (see `RootView`), not a constant:
    /// it depends on the device/orientation/safe areas.
    internal let maxHeight: CGFloat?

    private var isClamped: Bool {
        guard let idealHeight, let maxHeight else {
            return false
        }
        return idealHeight > maxHeight
    }

    private var detents: Set<PresentationDetent> {
        guard let idealHeight else {
            return [.medium]
        }
        if self.isClamped, let maxHeight {
            return [.height(maxHeight)]
        }
        return [.height(idealHeight)]
    }

    internal func body(content: Content) -> some View {
        Group {
            if self.isClamped {
                ScrollView {
                    self.measured(content)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                self.measured(content)
            }
        }
        .presentationDetents(self.detents)
    }

    private func measured(_ content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                self.idealHeight = newHeight
            }
    }
}

extension View {
    /// Sizes the sheet presenting this view to this view's own height,
    /// scrolling instead of clipping once that height exceeds `maxHeight`.
    ///
    /// Apply to the root of a `.sheet`'s content. See
    /// `FittedSheetModifier`'s doc comment for how.
    ///
    /// - Parameter maxHeight: the most height the sheet may occupy, as
    ///   measured by the presenting view; `nil` while unmeasured (the
    ///   sheet then falls back to `.medium` for its first frame).
    /// - Returns: this view, modified to size/scroll its presenting sheet.
    internal func fittedSheet(maxHeight: CGFloat?) -> some View {
        self.modifier(FittedSheetModifier(maxHeight: maxHeight))
    }
}

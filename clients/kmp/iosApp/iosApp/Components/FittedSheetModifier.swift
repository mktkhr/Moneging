import SwiftUI

/// Sizes a sheet to exactly a pre-measured content height, with no extra
/// empty space left below it.
///
/// Two official SwiftUI APIs, used together:
///
/// - A view reports its own ideal height via
///   `onGeometryChange(for:of:action:)`
///   (https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)),
///   after `fixedSize(horizontal:vertical:)` makes it lay out at that ideal
///   height rather than whatever height its container proposes - see
///   `measureHeight(into:)`.
/// - That measured height becomes a sheet's *only* `PresentationDetent`,
///   via `PresentationDetent.height(_:)`
///   (https://developer.apple.com/documentation/swiftui/presentationdetent/height(_:)),
///   applied through `presentationDetents(_:)`
///   (https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:)) -
///   see `fittedSheet(height:)`.
///
/// No hard-coded height anywhere: the detent tracks whatever the content
/// actually measures.
///
/// Measurement and presentation are deliberately two separate steps
/// (`measureHeight(into:)`, on a hidden copy of the content in ordinary,
/// non-modal layout, feeds `fittedSheet(height:)`, on the real one),
/// rather than a single view measuring itself while already presented as
/// the sheet's own content. A single-detent sheet has nothing to fall
/// back to before its content is first measured, so that pattern needs a
/// placeholder detent (typically `.medium`) for the sheet's first,
/// visible frame, then swaps to the real one once measured - a visible
/// resize the moment the sheet opens. Measuring ahead of time, in
/// `RootView`, means the sheet's very first presented frame already
/// carries the right detent, with no resize and no placeholder ever
/// shown.
///
/// `presentationSizing(_:)`
/// (https://developer.apple.com/documentation/swiftui/view/presentationsizing(_:))
/// with `.form.fitted(horizontal:vertical:)` was evaluated too (both here
/// and against the single-step pattern above), but made no measurable
/// difference on this iPhone-only project (compact width;
/// docs/handbook/architecture.md's iOS 26 target) and is left out rather
/// than kept on a guess.
internal struct FittedSheetModifier: ViewModifier {
    internal let height: CGFloat?

    internal func body(content: Content) -> some View {
        content
            .presentationDetents(self.height.map { [.height($0)] } ?? [.medium])
    }
}

extension View {
    /// Sizes this view's enclosing sheet to `height`.
    ///
    /// See `FittedSheetModifier`'s doc comment for where that height comes
    /// from and why measuring happens separately, via
    /// `measureHeight(into:)`.
    internal func fittedSheet(height: CGFloat?) -> some View {
        self.modifier(FittedSheetModifier(height: height))
    }

    /// Measures this view's own ideal height into `height`, without
    /// presenting it: `fixedSize(vertical:)` makes it lay out at its
    /// intrinsic height regardless of its container's proposal, and
    /// `onGeometryChange` reports that height. Pairs with
    /// `fittedSheet(height:)`, applied to an identical, visible copy of
    /// this same view - see `FittedSheetModifier`'s doc comment for why
    /// measurement and presentation are two separate views rather than
    /// one.
    internal func measureHeight(into height: Binding<CGFloat?>) -> some View {
        self
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { newHeight in
                height.wrappedValue = newHeight
            }
    }
}

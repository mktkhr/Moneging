import SwiftUI

/// Reports this view's frame as the tour target `target` whenever it moves.
internal struct TourTargetModifier: ViewModifier {
    internal let target: TourTarget
    internal let isReporting: Bool

    @Environment(TourLayout.self)
    private var layout: TourLayout

    internal func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            if self.isReporting {
                self.layout.report(self.target, frame: frame)
            }
        }
    }
}

extension View {
    /// Marks this view as the tour target `target`, reporting its frame
    /// while `isReporting` holds (on the ホーム tab).
    internal func tourTarget(_ target: TourTarget, isReporting: Bool) -> some View {
        self.modifier(TourTargetModifier(target: target, isReporting: isReporting))
    }
}

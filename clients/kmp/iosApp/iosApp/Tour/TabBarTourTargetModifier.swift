import SwiftUI

/// Reports the tab bar's controls as the tour target `.tabBar`, through a
/// `TabBarFrameReader` behind the modified view.
internal struct TabBarTourTargetModifier: ViewModifier {
    internal let isReporting: Bool

    @Environment(TourLayout.self)
    private var layout: TourLayout

    internal func body(content: Content) -> some View {
        content.background(alignment: .top) {
            TabBarFrameReader { frame in
                if self.isReporting {
                    self.layout.report(.tabBar, frame: frame)
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Marks the tab bar as the tour target `.tabBar`.
    ///
    /// Reports its controls' frame while `isReporting` holds (on the ホーム
    /// tab). Applied to a view at the top of the tab bar's area: the reader
    /// behind it extends down over that area.
    internal func tabBarTourTarget(isReporting: Bool) -> some View {
        self.modifier(TabBarTourTargetModifier(isReporting: isReporting))
    }
}

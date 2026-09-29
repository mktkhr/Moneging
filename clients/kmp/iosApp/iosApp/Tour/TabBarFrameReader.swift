import SwiftUI
import UIKit

/// Reports where the tab bar's controls are on screen, in window
/// coordinates: the capsule of the four tabs and the separate 検索 button
/// together.
///
/// Read from UIKit because SwiftUI cannot tell: on iOS 26 the Liquid Glass
/// bar floats, so neither the bottom safe-area inset the `TabView` adds nor
/// `UITabBar`'s own frame ends where the controls do (both run on to the
/// screen's bottom edge, below them). The view finds the tab bar of the
/// `UITabBarController` it is hosted in and unions the frames of the bar's
/// visible subviews, which are the controls' capsules; only public API is
/// used, the subviews are read as plain views. With none, the bar's own
/// frame is reported.
internal struct TabBarFrameReader: UIViewRepresentable {
    internal let onChange: (CGRect) -> Void

    internal func makeUIView(context _: Context) -> TabBarFrameReaderView {
        let view: TabBarFrameReaderView = TabBarFrameReaderView()
        view.isUserInteractionEnabled = false
        view.onChange = self.onChange
        return view
    }

    internal func updateUIView(_ uiView: TabBarFrameReaderView, context _: Context) {
        uiView.onChange = self.onChange
        uiView.setNeedsLayout()
    }
}

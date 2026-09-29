import UIKit

/// The view behind `TabBarFrameReader`.
///
/// Laid out over the tab bar's area, so it lays out again whenever that
/// area changes (another device, Dynamic Type, rotation) and reports the
/// controls' frame each time.
internal final class TabBarFrameReaderView: UIView {
    internal var onChange: ((CGRect) -> Void)?

    private var reportedFrame: CGRect?

    // The tab bar of the tab bar controller this view is hosted in.
    private var tabBar: UITabBar? {
        var responder: UIResponder? = self.next
        while let current = responder {
            if let found = (current as? UIViewController)?.tabBarController?.tabBar {
                return found
            }
            responder = current.next
        }
        return nil
    }

    override internal func didMoveToWindow() {
        super.didMoveToWindow()
        self.setNeedsLayout()
    }

    override internal func layoutSubviews() {
        super.layoutSubviews()
        // The tab bar lays out in the same pass, possibly after this view.
        Task { @MainActor [weak self] in
            self?.report()
        }
    }

    private func report() {
        guard let window = self.window, let tabBar = self.tabBar else {
            return
        }
        tabBar.layoutIfNeeded()
        let controls: CGRect = tabBar.subviews
            .filter { subview in
                !subview.isHidden && subview.alpha > 0 && !subview.bounds.isEmpty
            }
            .reduce(CGRect.null) { union, subview in
                union.union(subview.convert(subview.bounds, to: window))
            }
        let frame: CGRect = controls.isNull ? tabBar.convert(tabBar.bounds, to: window) : controls
        if frame != self.reportedFrame {
            self.reportedFrame = frame
            self.onChange?(frame)
        }
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}

import SwiftUI
import UIKit

/// A pan that begins only when it moves more sideways than up or down, so
/// the scroll view around it still scrolls; it reports how far it moved
/// sideways.
internal struct HorizontalPan: UIGestureRecognizerRepresentable {
    internal final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        internal func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else {
                return false
            }
            let velocity: CGPoint = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        deinit {
            // No teardown needed; explicit per the project's lint policy.
        }
    }

    internal let onChange: (CGFloat) -> Void
    internal let onEnd: (CGFloat) -> Void

    internal func makeCoordinator(converter _: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    internal func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer: UIPanGestureRecognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    internal func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer,
        context _: Context,
    ) {
        let translation: CGFloat = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            self.onChange(translation)

        case .ended, .cancelled, .failed:
            self.onEnd(translation)

        default:
            break
        }
    }
}

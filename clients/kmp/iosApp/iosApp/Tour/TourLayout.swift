import CoreFoundation
import Observation

/// Where the tour's targets are on screen, in global coordinates, reported
/// by the targets themselves (`tourTarget(_:)`).
///
/// Created once at the app root and shared through the environment. Only
/// the ホーム tab reports: the tour always runs over its root screen.
@MainActor
@Observable
internal final class TourLayout {
    /// Each target's frame in the window.
    internal private(set) var frames: [TourTarget: CGRect] = [:]

    internal init() {
        // Nothing to set up: frames arrive as the targets lay out.
    }

    /// Records where `target` is now.
    internal func report(_ target: TourTarget, frame: CGRect) {
        self.frames[target] = frame
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}

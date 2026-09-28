#if DEBUG
    import UIKit

    /// Turns the app's animations off when a UI test run asks for it.
    ///
    /// `make ios-ui-test` and `make acceptance-ios` set
    /// `TEST_RUNNER_UITestDisableAnimations=YES`; the test runner forwards it
    /// to the app as the launch argument `-UITestDisableAnimations YES`, which
    /// lands in `UserDefaults`' argument domain. Animations only make a UI
    /// test wait, so switching them off there shortens the run without
    /// changing what is on screen. Compiled in debug builds only: release
    /// builds never read the flag.
    @MainActor
    internal enum UITestAnimationSwitch {
        private static let launchArgumentKey: String = "UITestDisableAnimations"

        /// Disables UIKit (and so SwiftUI's UIKit-backed) animations when the
        /// launch argument asks for it; does nothing otherwise.
        internal static func applyLaunchArgument() {
            guard UserDefaults.standard.bool(forKey: self.launchArgumentKey) else {
                return
            }
            UIView.setAnimationsEnabled(false)
        }
    }
#endif

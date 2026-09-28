import XCTest

extension XCUIApplication {
    /// The app under test, launched the way every acceptance test launches it.
    ///
    /// `make acceptance-ios` and `make ios-ui-test` set
    /// `TEST_RUNNER_UITestDisableAnimations=YES`, which xcodebuild hands to
    /// this test runner as `UITestDisableAnimations`; it is forwarded to the
    /// app as the launch argument `-UITestDisableAnimations YES` (read through
    /// `UserDefaults`), so the app can switch its animations off.
    internal static func launchedForAcceptance(arguments: [String]) -> XCUIApplication {
        let app: XCUIApplication = XCUIApplication()
        let environment: [String: String] = ProcessInfo.processInfo.environment
        if let disableAnimations = environment["UITestDisableAnimations"] {
            app.launchArguments += ["-UITestDisableAnimations", disableAnimations]
        }
        app.launchArguments += arguments
        app.launch()
        return app
    }
}

# acceptance/ios

XCUITest sources for the `AC-F` and `AC-E` criteria of `PRODUCT.md` §7 on iOS.
Every `.swift` file here is compiled into the `iosAppAcceptanceTests` UI-test
target of `clients/kmp/iosApp/iosApp.xcodeproj` (a synchronized folder; this
README is excluded from the target) and run by the `iosAppAcceptance` scheme
through `make acceptance-ios`.

A Swift method name cannot contain `-`, so a test carries its criterion as
`AC_F_102` (underscores) in its class or method name, e.g.
`func test_AC_F_102_createsLedgerThroughOnboarding()`. `make status` matches
either spelling.

Launch the app with `XCUIApplication.launchedForAcceptance(arguments:)`
(`XCUIApplication+Acceptance.swift`): it forwards `UITestDisableAnimations`,
which the harness puts in the test runner's environment
(`TEST_RUNNER_UITestDisableAnimations=YES`), to the app as the launch argument
`-UITestDisableAnimations YES`. The sources are held to `swift-format` and
`swiftlint --strict` (`quality/swift/`) by `make acceptance-ios`.

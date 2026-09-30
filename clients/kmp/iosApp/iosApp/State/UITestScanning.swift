#if DEBUG
    import Foundation
    import SharedLogic

    /// What a UI test replaces of reading receipts.
    ///
    /// The contract of `acceptance/ios/XCUIApplication+Scanning.swift`,
    /// chosen by launch argument, read through the argument domain of
    /// `UserDefaults`:
    ///
    /// - `-UITestScannerFixtures <directory>`: the document scanner and the
    ///   photo library hand over the fixture pictures of
    ///   `<directory>/receipts`, and scans read them with the fixture scanner.
    /// - `-UITestScannerPages <names>` / `-UITestPickedPhotos <names>`: the
    ///   receipts (comma separated) a document-scanner session and a pick
    ///   from the photo library hand over.
    /// - `-UITestJobStepping YES`: scan jobs move one state per press of
    ///   `scan-job-step`.
    /// - `-UITestFakeProgressSurface YES`: the Live Activity is replaced by
    ///   the element `progress-surface` (`UITestProgressSurface`).
    /// - `-UITestModuleInstaller fake`: the module installer is replaced by
    ///   `UITestModuleInstaller`.
    /// - `-AcceptancePhotoReading YES`: reading from photos is on from the start.
    /// - `-UITestDeviceAi <on|off>`: Apple Intelligence is usable (`on`) or
    ///   turned off in the settings (`off`), whatever the device.
    /// - `-AcceptanceReadingMethod <ai|none>`: the reading method is chosen
    ///   from the start: Apple Intelligence or `AI を使わない`.
    ///
    /// Compiled in debug builds only: release builds never read the flags.
    @MainActor
    internal enum UITestScanning {
        private static let fixturesKey: String = "UITestScannerFixtures"
        private static let pagesKey: String = "UITestScannerPages"
        private static let pickedKey: String = "UITestPickedPhotos"
        private static let steppingKey: String = "UITestJobStepping"
        private static let fakeSurfaceKey: String = "UITestFakeProgressSurface"
        private static let installerKey: String = "UITestModuleInstaller"
        private static let photoReadingKey: String = "AcceptancePhotoReading"
        private static let fakeInstallerName: String = "fake"
        nonisolated private static let deviceAiKey: String = "UITestDeviceAi"
        private static let readingMethodKey: String = "AcceptanceReadingMethod"
        nonisolated private static let onValue: String = "on"
        private static let aiValue: String = "ai"
        private static let noneValue: String = "none"

        /// Whether Apple Intelligence is usable, as the launch argument sets
        /// it (`on`, `off`), or `nil` when the device decides.
        nonisolated internal static var deviceAi: String? {
            UserDefaults.standard.string(forKey: Self.deviceAiKey)
        }

        /// Whether the launch argument turns Apple Intelligence on.
        nonisolated internal static var isDeviceAiOn: Bool {
            Self.deviceAi == Self.onValue
        }

        /// The reading method chosen from the start, or `nil` when not chosen.
        internal static var chosenReadingMethod: ReadingMethod? {
            switch UserDefaults.standard.string(forKey: Self.readingMethodKey) {
            case Self.aiValue:
                return .deviceAi

            case Self.noneValue:
                return .noAi

            default:
                return nil
            }
        }

        /// The fixtures directory, or `nil` when the OS scanner is used.
        internal static let fixturesDirectory: String? = UserDefaults.standard.string(
            forKey: Self.fixturesKey,
        )

        /// Whether scan jobs move only on `scan-job-step`.
        internal static let isJobStepping: Bool = UserDefaults.standard.bool(
            forKey: Self.steppingKey,
        )

        /// Whether reading from photos is on from the start.
        internal static let isPhotoReadingEnabled: Bool = UserDefaults.standard.bool(
            forKey: Self.photoReadingKey,
        )

        /// The stand-in for the Live Activity, or `nil` when the real one is used.
        internal static let progressSurface: UITestProgressSurface? =
            UserDefaults.standard.bool(forKey: Self.fakeSurfaceKey) ? UITestProgressSurface() : nil

        /// The stand-in for the module installer, or `nil` when the real one is used.
        internal static let moduleInstaller: UITestModuleInstaller? =
            UserDefaults.standard.string(forKey: Self.installerKey) == Self.fakeInstallerName
            ? UITestModuleInstaller() : nil

        /// Whether the fixture pictures stand in for the document scanner
        /// and the photo library.
        internal static var isFixtureCapture: Bool {
            Self.fixturesDirectory != nil
        }

        /// The pictures a document-scanner session hands over, in a UI test.
        internal static var scannedPages: [Data] {
            Self.pictures(named: Self.pagesKey)
        }

        /// The pictures a pick from the photo library hands over, in a UI test.
        internal static var pickedPhotos: [Data] {
            Self.pictures(named: Self.pickedKey)
        }

        // The fixture pictures the launch argument `key` names.
        private static func pictures(named key: String) -> [Data] {
            guard let directory = Self.fixturesDirectory else {
                return []
            }
            let names: [String] = (UserDefaults.standard.string(forKey: key) ?? "")
                .split(separator: ",")
                .map(String.init)
            return names.compactMap { name in
                FileManager.default.contents(atPath: "\(directory)/receipts/\(name).jpg")
            }
        }
    }
#endif

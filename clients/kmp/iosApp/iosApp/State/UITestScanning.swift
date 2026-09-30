#if DEBUG
    import Foundation

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

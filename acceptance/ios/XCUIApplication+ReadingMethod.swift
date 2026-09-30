import XCTest

/// The elements of the reading method (AC-F-505); their identifiers are the
/// contract written in `XCUIApplication+Scanning.swift`.
extension XCUIApplication {
    /// The notice shown before a scan when the chosen AI cannot be used
    /// (`reading-unavailable-notice`).
    internal var readingUnavailableNotice: XCUIElement {
        self.anyElement("reading-unavailable-notice")
    }

    /// The notice's choice to read without AI
    /// (`reading-unavailable-without-ai`).
    internal var readWithoutAiButton: XCUIElement {
        self.buttons["reading-unavailable-without-ai"]
    }

    /// The notice's choice to open the settings
    /// (`reading-unavailable-open-settings`).
    internal var openReadingSettingsButton: XCUIElement {
        self.buttons["reading-unavailable-open-settings"]
    }

    /// The notice's choice to stop (`reading-unavailable-cancel`).
    internal var cancelReadingButton: XCUIElement {
        self.buttons["reading-unavailable-cancel"]
    }

    /// The line of the draft shown saying how it was read
    /// (`draft-reading-method`).
    internal var draftReadingMethod: XCUIElement {
        self.anyElement("draft-reading-method")
    }

    /// The row of 設定 showing the reading method (`settings-reading-method`).
    internal var settingsReadingMethodRow: XCUIElement {
        self.anyElement("settings-reading-method")
    }

    /// The choice of the device's AI on the reading method screen
    /// (`reading-method-option-ai`).
    internal var readingMethodAiOption: XCUIElement {
        self.anyElement("reading-method-option-ai")
    }

    /// The reason the device's AI cannot be chosen
    /// (`reading-method-reason-ai`).
    internal var readingMethodAiReason: XCUIElement {
        self.anyElement("reading-method-reason-ai")
    }

    /// The choice of reading without AI (`reading-method-option-none`).
    internal var readingMethodNoAiOption: XCUIElement {
        self.anyElement("reading-method-option-none")
    }

    /// An element of any kind with the identifier `identifier`.
    private func anyElement(_ identifier: String) -> XCUIElement {
        self.descendants(matching: .any)[identifier]
    }
}

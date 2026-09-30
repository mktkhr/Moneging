import Observation
import SharedLogic

/// `@Observable` adapter over the shared `ReadingMethods`: the device's
/// reading method (PRODUCT.md §3, Reading method), Apple Intelligence or
/// `AI を使わない`, and whether Apple Intelligence can be used now.
///
/// Created once at the app root (`MonegingApp`) and shared through the
/// environment. Whether the AI can be used is read again with `refresh()`,
/// since the user may turn it on or off in the OS settings meanwhile.
@MainActor
@Observable
internal final class ReadingMethodStore {
    /// The method scans are read by.
    internal private(set) var chosen: ReadingMethod
    /// Whether Apple Intelligence can be used now.
    internal private(set) var isDeviceAiUsable: Bool
    /// Why Apple Intelligence cannot be used, or `nil` when it can.
    internal private(set) var deviceAiUnavailableReason: String?

    private let methods: ReadingMethods

    /// Whether the chosen method cannot be used now (Apple Intelligence chosen and off).
    internal var isChosenUnusable: Bool {
        self.chosen == .deviceAi && !self.isDeviceAiUsable
    }

    /// The title of the notice shown before a scan when the chosen method cannot be used.
    internal var unusableTitle: String {
        self.methods.unusableTitle
    }

    internal init(methods: ReadingMethods) {
        self.methods = methods
        self.chosen = methods.chosen
        self.isDeviceAiUsable = methods.isDeviceAiUsable
        self.deviceAiUnavailableReason = methods.deviceAiUnavailableReason
    }

    /// The name of `method` (`Apple Intelligence`, `AI を使わない`).
    internal func name(of method: ReadingMethod) -> String {
        self.methods.nameOf(method: method)
    }

    /// Reads again whether Apple Intelligence can be used.
    internal func refresh() {
        self.chosen = self.methods.chosen
        self.isDeviceAiUsable = self.methods.isDeviceAiUsable
        self.deviceAiUnavailableReason = self.methods.deviceAiUnavailableReason
    }

    /// Keeps `method` as the device's choice.
    internal func choose(_ method: ReadingMethod) {
        self.methods.choose(method: method)
        self.refresh()
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}

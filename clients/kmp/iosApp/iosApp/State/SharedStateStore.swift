import Observation
import SharedLogic

/// `@Observable` adapter over the shared Kotlin `AppState`, consumed
/// through SKIE's `AsyncSequence` bridging of `StateFlow`.
///
/// Created once at the app root (`MonegingApp`) and shared through the
/// environment, so every tab observes the same month/ledger selection: a
/// change made on one tab is visible on every other tab. Intents are
/// forwarded back to the shared `AppState`; this adapter never mutates
/// its own properties directly, only from the state stream.
@MainActor
@Observable
internal final class SharedStateStore {
    /// The month currently displayed, 1-12.
    internal private(set) var selectedMonth: Int
    /// Every ledger the user can switch to.
    internal private(set) var ledgers: [Ledger]
    /// `Ledger.id` of the ledger currently selected.
    internal private(set) var selectedLedgerId: String

    private let appState: AppState
    /// Holds the observation loop reading `appState.uiState`, so `deinit`
    /// (not main-actor-isolated even on an `@MainActor` class - no
    /// isolated `deinit` here) can cancel it without needing main-actor
    /// isolation itself.
    ///
    /// A `let` box (`ObservationTaskBox`) around a `var`, not a plain
    /// `nonisolated var` property on `SharedStateStore` directly: Swift
    /// does not allow `nonisolated` on a mutable stored property, and this
    /// box is a separate object, so `@Observable`'s tracking macro does
    /// not apply to its mutation either.
    private let observationTask: ObservationTaskBox = ObservationTaskBox()

    /// The name of the ledger currently selected.
    internal var selectedLedgerName: String {
        self.ledgers.first { $0.id == self.selectedLedgerId }?.name ?? ""
    }

    internal init(appState: AppState) {
        self.appState = appState
        let initial: AppUiState = appState.uiState.value
        self.selectedMonth = Int(initial.selectedMonth)
        self.ledgers = initial.ledgers
        self.selectedLedgerId = initial.selectedLedgerId

        let stateFlow: SkieSwiftStateFlow<AppUiState> = appState.uiState
        let taskBox: ObservationTaskBox = self.observationTask
        taskBox.task = Task { [weak self] in
            for await state in stateFlow {
                guard let self else {
                    return
                }
                self.apply(state)
            }
        }
    }

    /// Sends a month-change intent to the shared `AppState`.
    internal func selectMonth(_ month: Int) {
        self.appState.onIntent(intent: AppIntentSelectMonth(month: Int32(month)))
    }

    /// Sends a ledger-change intent to the shared `AppState`.
    internal func selectLedger(id: String) {
        self.appState.onIntent(intent: AppIntentSelectLedger(ledgerId: id))
    }

    private func apply(_ state: AppUiState) {
        self.selectedMonth = Int(state.selectedMonth)
        self.ledgers = state.ledgers
        self.selectedLedgerId = state.selectedLedgerId
    }

    deinit {
        self.observationTask.task?.cancel()
    }
}

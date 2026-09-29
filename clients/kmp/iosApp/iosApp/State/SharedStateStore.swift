import Observation
import SharedLogic

/// `@Observable` adapter over the shared Kotlin `AppState`, consumed
/// through SKIE's `AsyncSequence` bridging of `StateFlow`.
///
/// Created once at the app root (`MonegingApp`) and shared through the
/// environment, so every tab observes the same state: a change made on one
/// tab is visible on every other tab. Intents and writes are forwarded to
/// the shared `AppState`; this adapter never mutates its own properties
/// directly, only from the state `AppState` publishes. After an intent or a
/// write it reads that state at once, so the screen shows the change before
/// the next frame rather than when the stream delivers it.
@MainActor
@Observable
internal final class SharedStateStore {
    /// The year of the month in view.
    internal private(set) var selectedYear: Int
    /// The month in view, 1-12.
    internal private(set) var selectedMonth: Int
    /// The month in view as the header names it (`2月`, or `2025年2月` in
    /// another year than today's).
    internal private(set) var selectedMonthTitle: String
    /// Today by the app's clock, ISO (`2026-02-15`).
    internal private(set) var todayIso: String
    /// The month of today, ISO (`2026-02`).
    internal private(set) var todayMonthIso: String
    /// Whether the ledgers and the tour's progress have been read from the device.
    internal private(set) var isLoaded: Bool
    /// Every ledger the user can change to, in creation order.
    internal private(set) var ledgers: [Ledger]
    /// `Ledger.id` of the ledger in view, as text; empty before the first
    /// ledger exists.
    internal private(set) var selectedLedgerId: String
    /// The day the ledger in view was created, ISO (`2026-02-02`); `nil`
    /// before the first ledger exists.
    internal private(set) var selectedLedgerCreatedOnIso: String?
    /// The name the header shows for the ledger in view (while the tour's
    /// ledger step is shown, the name being typed).
    internal private(set) var selectedLedgerName: String
    /// The tour step shown, or `nil`.
    internal private(set) var tour: TourState?
    /// The name typed in the tour's ledger step.
    internal private(set) var ledgerNameDraft: String
    /// A failed operation the shared state reports, or `nil`.
    internal private(set) var errorMessage: String?
    /// A write that failed without the shared state reporting it, or `nil`.
    internal private(set) var writeFailureMessage: String?

    /// The failed operation to tell the user about, or `nil`.
    internal var shownErrorMessage: String? {
        self.errorMessage ?? self.writeFailureMessage
    }

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

    internal init(appState: AppState) {
        self.appState = appState
        let initial: AppUiState = appState.uiState.value
        self.selectedYear = Int(initial.selectedYear)
        self.selectedMonth = Int(initial.selectedMonthNumber)
        self.selectedMonthTitle = initial.selectedMonthTitle
        self.todayIso = initial.todayIso
        self.todayMonthIso = initial.todayMonthIso
        self.isLoaded = initial.isLoaded
        self.ledgers = initial.ledgers
        self.selectedLedgerId = initial.selectedLedgerId ?? ""
        self.selectedLedgerCreatedOnIso = initial.selectedLedgerCreatedOnIso
        self.selectedLedgerName = initial.ledgerTitle
        self.tour = initial.tour
        self.ledgerNameDraft = initial.ledgerNameDraft
        self.errorMessage = initial.errorMessage

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

    /// Whether `name` names a ledger under the shared rule: trimmed, 1 to
    /// 20 characters as the user sees them.
    internal static func isValidLedgerName(_ name: String) -> Bool {
        LedgerName.shared.isValid(input: name)
    }

    /// Shows the month `month` (1-12) of `year`.
    internal func selectMonth(year: Int, month: Int) {
        self.send(AppIntentSelectMonth(year: Int32(year), month: Int32(month)))
    }

    /// Shows the ledger `id` (`Ledger.id` as text).
    internal func selectLedger(id: String) {
        self.send(AppIntentSelectLedger(ledgerId: id))
    }

    /// Changes the name typed in the tour's ledger step.
    internal func changeLedgerNameDraft(_ name: String) {
        self.send(AppIntentChangeLedgerNameDraft(name: name))
    }

    /// Moves the tour to its next step, ending it after the last.
    internal func advanceTour() {
        self.send(AppIntentAdvanceTour.shared)
    }

    /// Skips the rest of the tour.
    internal func skipTour() {
        self.send(AppIntentSkipTour.shared)
    }

    /// Replays the tour from the step after the ledger step.
    internal func replayTour() {
        self.send(AppIntentReplayTour.shared)
    }

    /// Dismisses the error shown.
    internal func dismissError() {
        self.writeFailureMessage = nil
        self.send(AppIntentDismissError.shared)
    }

    /// Creates the first ledger with the name typed in the tour's ledger
    /// step and moves the tour on.
    internal func createFirstLedger() async {
        await self.write { try await self.appState.createFirstLedger() }
    }

    /// Adds a ledger named `name` and shows it; returns whether it was added.
    internal func addLedger(named name: String) async -> Bool {
        await self.write { try await self.appState.addLedger(name: name) }
    }

    /// Renames the ledger `id`; returns whether it was renamed.
    internal func renameLedger(id: String, to name: String) async -> Bool {
        await self.write { try await self.appState.renameLedger(ledgerId: id, name: name) }
    }

    private func send(_ intent: AppIntent) {
        self.appState.onIntent(intent: intent)
        self.apply(self.appState.uiState.value)
    }

    // Runs a write of the shared state, then shows the state it left. A
    // failure the shared state did not report itself is shown here.
    @discardableResult
    private func write(_ operation: () async throws -> KotlinBoolean) async -> Bool {
        let isDone: Bool
        do {
            isDone = try await operation().boolValue
        } catch {
            self.writeFailureMessage = String(localized: "保存できませんでした")
            return false
        }
        self.apply(self.appState.uiState.value)
        return isDone
    }

    private func apply(_ state: AppUiState) {
        self.selectedYear = Int(state.selectedYear)
        self.selectedMonth = Int(state.selectedMonthNumber)
        self.selectedMonthTitle = state.selectedMonthTitle
        self.todayIso = state.todayIso
        self.todayMonthIso = state.todayMonthIso
        self.isLoaded = state.isLoaded
        self.ledgers = state.ledgers
        self.selectedLedgerId = state.selectedLedgerId ?? ""
        self.selectedLedgerCreatedOnIso = state.selectedLedgerCreatedOnIso
        self.selectedLedgerName = state.ledgerTitle
        self.tour = state.tour
        self.ledgerNameDraft = state.ledgerNameDraft
        self.errorMessage = state.errorMessage
    }

    deinit {
        self.observationTask.task?.cancel()
    }
}

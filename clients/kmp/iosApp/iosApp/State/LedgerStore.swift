import Observation
import SharedLogic

/// `@Observable` adapter over the shared Kotlin `LedgerData` (the records of
/// the ledger in view) and `LedgerEditor` (their writes), consumed through
/// SKIE's `AsyncSequence` bridging of `StateFlow`.
///
/// Created once at the app root (`MonegingApp`) and shared through the
/// environment, like `SharedStateStore`. A write returns whether it was
/// done; a refusal is kept in `failureMessage` for the screen to show.
@MainActor
@Observable
internal final class LedgerStore {
    /// The records of the ledger in view, for the month in view.
    internal private(set) var state: LedgerUiState
    /// The month's transactions grouped by day, newest first.
    internal private(set) var daySections: [DaySection]
    /// The count of needs-review records on home, or `nil` while none is marked.
    internal private(set) var reviewStatus: ReviewStatus?
    /// The needs-review records grouped by day, newest first, whatever their month.
    internal private(set) var reviewSections: [ReviewSection]
    /// Why the last write was refused, or `nil`.
    internal var failureMessage: String?

    private let ledgerData: LedgerData
    private let editor: LedgerEditor
    /// Holds the observation loop; see `SharedStateStore.observationTask`.
    private let observationTask: ObservationTaskBox = ObservationTaskBox()

    internal init(ledgerData: LedgerData, editor: LedgerEditor) {
        self.ledgerData = ledgerData
        self.editor = editor
        let initial: LedgerUiState = ledgerData.uiState.value
        self.state = initial
        self.daySections = initial.daySections()
        self.reviewStatus = initial.reviewStatus()
        self.reviewSections = initial.reviewSections()

        let stateFlow: SkieSwiftStateFlow<LedgerUiState> = ledgerData.uiState
        let taskBox: ObservationTaskBox = self.observationTask
        taskBox.task = Task { [weak self] in
            for await published in stateFlow {
                guard let self else {
                    return
                }
                self.apply(published)
            }
        }
    }

    /// The category `id` (`Category.id` as text), or `nil`.
    internal func category(id: String?) -> SharedLogic.Category? {
        guard let id else {
            return nil
        }
        return self.state.categories.first { $0.id.description == id }
    }

    /// The transaction `id` of the month in view or marked needs-review, or `nil`.
    internal func transaction(id: String) -> Transaction? {
        self.state.transactions.first { $0.id.description == id }
            ?? self.state.reviewNeededTransaction(id: id)
    }

    /// Why the transaction `id` is marked needs-review, or `nil` when it is not.
    internal func reviewExplanation(id: String) -> ReviewExplanation? {
        self.state.reviewExplanation(id: id)
    }

    /// Marks the transaction `id` reviewed as it is; returns whether it was saved.
    internal func markReviewed(id: String) async -> Bool {
        await self.write { try await self.editor.markReviewed(transactionId: id) }
    }

    /// Reads today again and records the recurring rules whose date has
    /// come; on returning to the foreground.
    internal func onForeground() {
        self.ledgerData.onForeground()
    }

    /// Moves today when the day has changed; as time passes.
    internal func onTimePassed() {
        self.ledgerData.onTimePassed()
    }

    /// Records `draft`; returns whether it was recorded.
    internal func record(_ draft: TransactionDraft) async -> Bool {
        await self.write { try await self.editor.recordTransaction(draft: draft) }
    }

    /// Replaces the transaction `id` with `draft`; returns whether it was changed.
    internal func update(id: String, with draft: TransactionDraft) async -> Bool {
        await self.write {
            try await self.editor.updateTransaction(transactionId: id, draft: draft)
        }
    }

    /// Deletes the transaction `id`; returns whether it was deleted.
    internal func delete(id: String) async -> Bool {
        await self.write { try await self.editor.deleteTransaction(transactionId: id) }
    }

    /// Adds a category named `name`; returns whether it was added.
    internal func createCategory(named name: String) async -> Bool {
        await self.write { try await self.editor.createCategory(name: name) }
    }

    /// Renames the category `id` to `name`; returns whether it was renamed.
    internal func renameCategory(id: String, to name: String) async -> Bool {
        await self.write { try await self.editor.renameCategory(categoryId: id, name: name) }
    }

    /// Archives the category `id`; returns whether it was archived.
    internal func archiveCategory(id: String) async -> Bool {
        await self.write { try await self.editor.archiveCategory(categoryId: id) }
    }

    /// Adds the recurring rule `draft` and records its months whose date
    /// has come; returns whether it was added.
    internal func createRecurringRule(_ draft: RecurringRuleDraft) async -> Bool {
        await self.write { try await self.editor.recurringRules.createRecurringRule(draft: draft) }
    }

    /// Replaces the recurring rule `id` with `draft` and records its months
    /// whose date has come; returns whether it was changed.
    internal func updateRecurringRule(id: String, with draft: RecurringRuleDraft) async -> Bool {
        await self.write {
            try await self.editor.recurringRules.updateRecurringRule(ruleId: id, draft: draft)
        }
    }

    /// Ends the recurring rule `id` with the last month it recorded;
    /// returns whether it was ended.
    internal func endRecurringRule(id: String) async -> Bool {
        await self.write { try await self.editor.recurringRules.endRecurringRule(ruleId: id) }
    }

    /// Deletes the recurring rule `id`, keeping what it recorded; returns
    /// whether it was deleted.
    internal func deleteRecurringRule(id: String) async -> Bool {
        await self.write { try await self.editor.recurringRules.deleteRecurringRule(ruleId: id) }
    }

    /// Sets the budget of `categoryId` (`nil` for the whole month) to
    /// `amountText` from the ISO month `fromMonth` on; returns whether it
    /// was set.
    internal func setBudget(
        categoryId: String?,
        amountText: String,
        fromMonth: String,
    ) async -> Bool {
        await self.write {
            try await self.editor.budgets.setBudget(
                categoryId: categoryId,
                amountText: amountText,
                fromMonth: fromMonth,
            )
        }
    }

    /// Removes the budget of `categoryId` (`nil` for the whole month) from
    /// the ISO month `fromMonth` on; returns whether it was removed.
    internal func removeBudget(categoryId: String?, fromMonth: String) async -> Bool {
        await self.write {
            try await self.editor.budgets.removeBudget(categoryId: categoryId, fromMonth: fromMonth)
        }
    }

    /// Changes the ledger's carry-over policy; returns whether it was changed.
    internal func setCarryOverPolicy(_ policy: CarryOverPolicy) async -> Bool {
        await self.write { try await self.editor.budgets.setCarryOverPolicy(policy: policy) }
    }

    /// Keeps `policy` for the ledger and closes the ISO month `month` under
    /// it; returns whether it was closed.
    internal func closeMonth(_ month: String, policy: CarryOverPolicy) async -> Bool {
        await self.write { try await self.editor.budgets.closeMonth(month: month, policy: policy) }
    }

    /// The transactions of the ledger in view matching `draft`; empty when
    /// the search fails, which is kept in `failureMessage`.
    internal func search(_ draft: SearchDraft) async -> [Transaction] {
        do {
            return try await self.editor.search(draft: draft)
        } catch {
            self.failureMessage = String(localized: "検索できませんでした")
            return []
        }
    }

    // Runs a write; a refusal (a returned reason) or a failure is kept in
    // `failureMessage`.
    private func write(_ operation: () async throws -> String?) async -> Bool {
        do {
            if let refusal = try await operation() {
                self.failureMessage = refusal
                return false
            }
            return true
        } catch {
            self.failureMessage = String(localized: "保存できませんでした")
            return false
        }
    }

    private func apply(_ state: LedgerUiState) {
        self.state = state
        self.daySections = state.daySections()
        self.reviewStatus = state.reviewStatus()
        self.reviewSections = state.reviewSections()
    }

    deinit {
        self.observationTask.task?.cancel()
    }
}

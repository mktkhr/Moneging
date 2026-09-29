package io.github.mktkhr.moneging.state

/**
 * User intents [AppState] applies at once. The UI only ever sends an intent
 * and reads the resulting [AppUiState] back; it never mutates state
 * directly. Changes that write the database are [AppState]'s suspend
 * functions instead.
 */
sealed interface AppIntent {
    /** Change the displayed month. */
    data class SelectMonth(
        /** The new month, 1-12. */
        val month: Int,
    ) : AppIntent

    /** Change the ledger in view. */
    data class SelectLedger(
        /** The identifier (`Ledger.id`) of the ledger to show. */
        val ledgerId: String,
    ) : AppIntent

    /** Change the name typed in the tour's ledger step. */
    data class ChangeLedgerNameDraft(
        /** The name as typed. */
        val name: String,
    ) : AppIntent

    /** Move the tour to its next step, ending it after the last. */
    data object AdvanceTour : AppIntent

    /** Skip the rest of the tour. */
    data object SkipTour : AppIntent

    /** Replay the tour from the settings, from the step after the ledger step. */
    data object ReplayTour : AppIntent

    /** Dismiss the error shown. */
    data object DismissError : AppIntent
}

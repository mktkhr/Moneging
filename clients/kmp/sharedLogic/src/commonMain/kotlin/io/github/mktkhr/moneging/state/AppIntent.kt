package io.github.mktkhr.moneging.state

/**
 * User intents [AppState] accepts. The UI only ever sends an intent and
 * reads the resulting [AppUiState] back; it never mutates state directly.
 */
sealed interface AppIntent {
    /** Change the displayed month. */
    data class SelectMonth(
        /** The new month, 1-12. */
        val month: Int,
    ) : AppIntent

    /** Change the selected ledger. */
    data class SelectLedger(
        /** [Ledger.id] of the ledger to select. */
        val ledgerId: String,
    ) : AppIntent
}

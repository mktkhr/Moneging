package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.Ledger

/**
 * The single state shared by every tab. [AppState] publishes this as a
 * single `StateFlow`; the UI never derives its own copy.
 */
data class AppUiState(
    /** The displayed month, 1-12. */
    val selectedMonth: Int,
    /** Whether the ledgers and the tour's progress have been read from the device. */
    val isLoaded: Boolean,
    /** Every ledger the user can change to, in creation order. */
    val ledgers: List<Ledger>,
    /** The identifier (`Ledger.id`) of the ledger in view, or `null` before the first ledger exists. */
    val selectedLedgerId: String?,
    /** The tour step shown, or `null` when the tour is not shown. */
    val tour: TourState?,
    /** The name typed in the tour's ledger step. */
    val ledgerNameDraft: String,
    /** A failed operation to tell the user about, or `null`. */
    val errorMessage: String?,
) {
    /** The ledger in view, or `null` before the first ledger exists. */
    val selectedLedger: Ledger?
        get() = ledgers.firstOrNull { it.id.toString() == selectedLedgerId }

    /**
     * The name the header shows for the ledger in view: while the tour's
     * ledger step is shown, the name being typed.
     */
    val ledgerTitle: String
        get() = if (tour?.step == TourStep.LEDGER) ledgerNameDraft else selectedLedger?.name.orEmpty()
}

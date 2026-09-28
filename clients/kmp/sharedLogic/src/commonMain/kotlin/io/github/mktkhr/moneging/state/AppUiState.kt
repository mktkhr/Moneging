package io.github.mktkhr.moneging.state

/**
 * The single state shared by every tab: the month currently displayed and
 * the ledger currently selected. [AppViewModel] publishes this as a single
 * `StateFlow`; the UI never derives its own copy.
 */
data class AppUiState(
    /** The displayed month, 1-12. */
    val selectedMonth: Int,
    /** Every ledger the user can switch to. */
    val ledgers: List<Ledger>,
    /** [Ledger.id] of the ledger currently selected. */
    val selectedLedgerId: String,
) {
    /** The [Ledger] matching [selectedLedgerId]. */
    val selectedLedger: Ledger
        get() = ledgers.first { it.id == selectedLedgerId }
}

package io.github.mktkhr.moneging.state

/**
 * The single state shared by every tab: the month currently displayed and
 * the ledger currently selected. [AppState] publishes this as a single
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
    /**
     * The [Ledger] matching [selectedLedgerId], or `null` if [selectedLedgerId]
     * does not match any entry in [ledgers] (defensive: [AppState] only ever
     * selects a known ledger, but this reader makes no such assumption).
     */
    val selectedLedger: Ledger?
        get() = ledgers.firstOrNull { it.id == selectedLedgerId }
}

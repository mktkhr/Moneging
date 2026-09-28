package io.github.mktkhr.moneging.state

import kotlin.test.Test
import kotlin.test.assertEquals

private const val SELECTED_MONTH = 4
private const val MONTH_BELOW_RANGE = 0
private const val MONTH_ABOVE_RANGE = 13
private const val UNKNOWN_LEDGER_ID = "does-not-exist"

/**
 * Verifies [AppState] follows the unidirectional flow the shared UI
 * state relies on: an [AppIntent] produces the next [AppUiState], with no
 * other way to mutate it.
 */
class AppStateTest {
    /**
     * [AppIntent.SelectMonth] updates [AppUiState.selectedMonth] and leaves
     * the selected ledger untouched.
     */
    @Test
    fun selectMonthUpdatesOnlyTheMonth() {
        val state = AppState()
        val ledgerBefore = state.uiState.value.selectedLedgerId

        state.onIntent(AppIntent.SelectMonth(month = SELECTED_MONTH))

        assertEquals(expected = SELECTED_MONTH, actual = state.uiState.value.selectedMonth)
        assertEquals(expected = ledgerBefore, actual = state.uiState.value.selectedLedgerId)
    }

    /** A month below 1 is ignored: the state stays exactly what it was. */
    @Test
    fun selectMonthIgnoresBelowRange() {
        val state = AppState()
        val monthBefore = state.uiState.value.selectedMonth

        state.onIntent(AppIntent.SelectMonth(month = MONTH_BELOW_RANGE))

        assertEquals(expected = monthBefore, actual = state.uiState.value.selectedMonth)
    }

    /** A month above 12 is ignored: the state stays exactly what it was. */
    @Test
    fun selectMonthIgnoresAboveRange() {
        val state = AppState()
        val monthBefore = state.uiState.value.selectedMonth

        state.onIntent(AppIntent.SelectMonth(month = MONTH_ABOVE_RANGE))

        assertEquals(expected = monthBefore, actual = state.uiState.value.selectedMonth)
    }

    /**
     * [AppIntent.SelectLedger] updates [AppUiState.selectedLedger] to the
     * chosen ledger.
     */
    @Test
    fun selectLedgerUpdatesLedger() {
        val state = AppState()
        val otherLedger =
            state.uiState.value.ledgers
                .last()

        state.onIntent(AppIntent.SelectLedger(ledgerId = otherLedger.id))

        assertEquals(expected = otherLedger, actual = state.uiState.value.selectedLedger)
    }

    /** An unknown ledger id is ignored: the selected ledger stays what it was. */
    @Test
    fun selectLedgerIgnoresUnknownId() {
        val state = AppState()
        val ledgerBefore = state.uiState.value.selectedLedgerId

        state.onIntent(AppIntent.SelectLedger(ledgerId = UNKNOWN_LEDGER_ID))

        assertEquals(expected = ledgerBefore, actual = state.uiState.value.selectedLedgerId)
    }
}

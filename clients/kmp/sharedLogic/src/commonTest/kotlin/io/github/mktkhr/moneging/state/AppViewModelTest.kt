package io.github.mktkhr.moneging.state

import kotlin.test.Test
import kotlin.test.assertEquals

private const val SELECTED_MONTH = 4

/**
 * Verifies [AppViewModel] follows the unidirectional flow the shared UI
 * state relies on: an [AppIntent] produces the next [AppUiState], with no
 * other way to mutate it.
 */
class AppViewModelTest {
    /**
     * [AppIntent.SelectMonth] updates [AppUiState.selectedMonth] and leaves
     * the selected ledger untouched.
     */
    @Test
    fun selectMonthUpdatesOnlyTheMonth() {
        val viewModel = AppViewModel()
        val ledgerBefore = viewModel.uiState.value.selectedLedgerId

        viewModel.onIntent(AppIntent.SelectMonth(month = SELECTED_MONTH))

        assertEquals(expected = SELECTED_MONTH, actual = viewModel.uiState.value.selectedMonth)
        assertEquals(expected = ledgerBefore, actual = viewModel.uiState.value.selectedLedgerId)
    }

    /**
     * [AppIntent.SelectLedger] updates [AppUiState.selectedLedger] to the
     * chosen ledger.
     */
    @Test
    fun selectLedgerUpdatesLedger() {
        val viewModel = AppViewModel()
        val otherLedger =
            viewModel.uiState.value.ledgers
                .last()

        viewModel.onIntent(AppIntent.SelectLedger(ledgerId = otherLedger.id))

        assertEquals(expected = otherLedger, actual = viewModel.uiState.value.selectedLedger)
    }
}

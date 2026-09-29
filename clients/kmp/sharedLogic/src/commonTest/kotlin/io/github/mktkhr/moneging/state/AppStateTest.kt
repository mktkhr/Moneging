package io.github.mktkhr.moneging.state

import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.YearMonth
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

private const val SELECTED_YEAR = 2026
private const val SELECTED_MONTH = 4
private const val MONTH_BELOW_RANGE = 0
private const val MONTH_ABOVE_RANGE = 13
private const val UNKNOWN_LEDGER_ID = "does-not-exist"
private const val TWENTY_ONE_CHARACTERS = "あいうえおかきくけこさしすせそたちつてとな"

/**
 * Verifies [AppState]'s unidirectional flow for the month and the ledgers:
 * an intent or a write produces the next [AppUiState], and the app reopens
 * on the ledger last in view. The tour is [TourTest]'s.
 */
class AppStateTest {
    private val device = TestDevice()

    /** Stops the app states the test launched. */
    @AfterTest
    fun tearDown() {
        device.close()
    }

    /** [AppIntent.SelectMonth] updates the month and leaves the ledger in view untouched. */
    @Test
    fun selectMonthUpdatesOnlyTheMonth(): TestResult =
        runTest {
            device.store.createLedger("家計")
            val state = device.launch()
            val ledgerBefore = state.ui.selectedLedgerId

            state.onIntent(AppIntent.SelectMonth(year = SELECTED_YEAR, month = SELECTED_MONTH))

            assertEquals(
                expected = YearMonth(year = SELECTED_YEAR, month = SELECTED_MONTH),
                actual = state.ui.selectedMonth,
            )
            assertEquals(expected = ledgerBefore, actual = state.ui.selectedLedgerId)
        }

    /** A month outside 1-12 is ignored. */
    @Test
    fun selectMonthIgnoresOutOfRange(): TestResult =
        runTest {
            val state = device.launch()
            val monthBefore = state.ui.selectedMonth

            state.onIntent(AppIntent.SelectMonth(year = SELECTED_YEAR, month = MONTH_BELOW_RANGE))
            state.onIntent(AppIntent.SelectMonth(year = SELECTED_YEAR, month = MONTH_ABOVE_RANGE))

            assertEquals(expected = monthBefore, actual = state.ui.selectedMonth)
        }

    /** An added ledger is shown, and the app reopens on the ledger last in view. */
    @Test
    fun addedLedgerIsShownAndKept(): TestResult =
        runTest {
            device.store.createLedger("家計")
            val state = device.launch()

            assertTrue(state.addLedger(name = "旅行"))

            assertEquals(expected = "旅行", actual = state.ui.ledgerTitle)
            assertEquals(expected = listOf("家計", "旅行"), actual = state.ledgerNames)
            assertEquals(expected = "旅行", actual = device.launch().ui.ledgerTitle)
        }

    /** A ledger with a refused name is not added, and the refusal is shown until dismissed. */
    @Test
    fun refusedLedgerIsReported(): TestResult =
        runTest {
            device.store.createLedger("家計")
            val state = device.launch()

            assertFalse(state.addLedger(name = TWENTY_ONE_CHARACTERS))

            assertEquals(expected = listOf("家計"), actual = state.ledgerNames)
            assertTrue(
                state.ui.errorMessage
                    .orEmpty()
                    .isNotEmpty(),
                "拒否の理由が示されない",
            )
            state.onIntent(AppIntent.DismissError)
            assertEquals(expected = null, actual = state.ui.errorMessage)
        }

    /** Choosing a ledger shows it; an unknown one is ignored. */
    @Test
    fun selectLedgerShowsKnownOnly(): TestResult =
        runTest {
            val kakei = device.store.createLedger("家計")
            val trip = device.store.createLedger("旅行")
            val state = device.launch()

            state.onIntent(AppIntent.SelectLedger(ledgerId = UNKNOWN_LEDGER_ID))
            assertEquals(expected = "家計", actual = state.ui.ledgerTitle)

            state.onIntent(AppIntent.SelectLedger(ledgerId = trip.id.toString()))
            assertEquals(expected = "旅行", actual = state.ui.ledgerTitle)

            state.onIntent(AppIntent.SelectLedger(ledgerId = kakei.id.toString()))
            assertEquals(expected = "家計", actual = state.ui.ledgerTitle)
        }

    /** Renaming a ledger not in view keeps the ledger in view; a refused name changes nothing. */
    @Test
    fun renameKeepsTheLedgerInView(): TestResult =
        runTest {
            device.store.createLedger("家計")
            val trip = device.store.createLedger("旅行")
            val state = device.launch()

            assertTrue(state.renameLedger(ledgerId = trip.id.toString(), name = "沖縄旅行"))
            assertFalse(state.renameLedger(ledgerId = trip.id.toString(), name = TWENTY_ONE_CHARACTERS))

            assertEquals(expected = "家計", actual = state.ui.ledgerTitle)
            assertEquals(expected = listOf("家計", "沖縄旅行"), actual = state.ledgerNames)
        }
}

package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Shares
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

private const val TODAY = "2026-02-15"
private const val CREATED_ON = "2026-02-02"
private const val THIRD_AMOUNT = 4_000L
private const val SMALL = 1L
private const val LARGE = 2L
private const val THIRD_ROUNDED_UP = 34
private const val THIRD_ROUNDED_DOWN = 33
private const val TWO_THIRDS_ROUNDED_UP = 67
private const val DAYS_IN_FEBRUARY = 28
private const val TREND_MONTHS = 12

/** How the calendar and the report show the month in view. */
class ReportPresentationTest {
    /** Whole percentages add up to 100 by the largest remainders, the earlier first on a tie. */
    @Test
    fun percentagesAddUpToOneHundred() {
        assertEquals(
            expected = listOf(THIRD_ROUNDED_UP, THIRD_ROUNDED_DOWN, THIRD_ROUNDED_DOWN),
            actual = Shares.percentages(listOf(SMALL, SMALL, SMALL)),
        )
        assertEquals(
            expected = listOf(TWO_THIRDS_ROUNDED_UP, THIRD_ROUNDED_DOWN),
            actual = Shares.percentages(listOf(LARGE, SMALL)),
        )
        assertEquals(expected = listOf(0, 0), actual = Shares.percentages(listOf(0L, 0L)))
    }

    /** A day shows its spending, a past day without any the NMD badge, except before the ledger and from today on. */
    @Test
    fun calendarNamesEachDay(): TestResult =
        runTest {
            val state = february()

            val calendar = assertNotNull(state.calendarMonth(todayIso = TODAY, ledgerCreatedOnIso = CREATED_ON))

            assertEquals(expected = DAYS_IN_FEBRUARY, actual = calendar.days.size)
            // 2026-02-01 is a Sunday: no empty cell before it.
            assertEquals(expected = 0, actual = calendar.leadingBlankDays)
            val labels = calendar.days.associate { it.date to it.accessibilityLabel }
            assertEquals(expected = "2月1日", actual = labels["2026-02-01"])
            assertEquals(expected = "2月2日 NMD", actual = labels["2026-02-02"])
            assertEquals(expected = "2月3日 4,000円", actual = labels["2026-02-03"])
            assertEquals(expected = "2月15日", actual = labels["2026-02-15"])
            assertEquals(expected = "2月20日", actual = labels["2026-02-20"])
            assertEquals(expected = "4,000", actual = calendar.days[2].amountText)
        }

    /** The report lists the share with whole percentages and twelve months of trend. */
    @Test
    fun reportListsShareAndTrend(): TestResult =
        runTest {
            val state = february()

            val report = assertNotNull(state.monthReport())

            assertEquals(expected = listOf("食費 4,000円 100%"), actual = report.shares.map { it.accessibilityLabel })
            assertEquals(expected = "2月の内訳", actual = report.shareTitle)
            assertEquals(expected = TREND_MONTHS, actual = report.trend.size)
            assertEquals(expected = "2026年2月 4,000円", actual = report.trend.last().accessibilityLabel)
            assertEquals(expected = "2025年3月〜2026年2月", actual = report.trendRange)
        }

    // February 2026 with 4,000円 of 食費 on the 3rd, as the ledger in view shows it.
    private suspend fun february(): LedgerUiState {
        val device = TestDevice()
        val ledger = device.store.createLedger("家計")
        val scope = device.store.ledger(ledger.id)
        val food = scope.categories().first { it.name == "食費" }
        scope.recordTransaction(
            NewTransaction(
                date = LocalDate.parse("2026-02-03"),
                direction = Direction.EXPENSE,
                amount = THIRD_AMOUNT,
                categoryId = food.id,
            ),
        )
        val month = YearMonth.parse("2026-02")
        return LedgerUiState.EMPTY.copy(
            ledgerId = ledger.id.toString(),
            month = month,
            isLoaded = true,
            totals = scope.monthTotals(month),
            report = scope.monthlyReport(month),
            dailyTotals = scope.dailyTotals(month),
            trend = scope.monthlyTrend(to = month),
            categories = scope.categories(),
        )
    }
}

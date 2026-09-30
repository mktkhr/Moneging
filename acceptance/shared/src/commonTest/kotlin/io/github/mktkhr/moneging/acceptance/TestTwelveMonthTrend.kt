package io.github.mktkhr.moneging.acceptance

import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals

private const val APRIL_2025 = 1_000L
private const val FEBRUARY_2026 = 2_000L
private const val FEBRUARY_2025 = 400L
private const val INCOME = 5_000L

// The twelve months from 2025-03 to 2026-02, in order.
private val TREND_MONTHS: List<String> =
    listOf(
        "2025-03",
        "2025-04",
        "2025-05",
        "2025-06",
        "2025-07",
        "2025-08",
        "2025-09",
        "2025-10",
        "2025-11",
        "2025-12",
        "2026-01",
        "2026-02",
    )

/**
 * AC-B-303 — The last twelve months report a total each.
 *
 * Given expenses of 1,000 in 2025-04, 2,000 in 2026-02 and 400 in 2025-02,
 * and an income of 5,000 in 2026-02. When the trend to 2026-02 is read, then
 * twelve entries are returned in order from 2025-03 to 2026-02, 2025-04 is
 * 1,000, 2026-02 is 2,000, and the rest are 0.
 */
class TestTwelveMonthTrend {
    /** The trend to 2026-02 has twelve months from 2025-03: 1,000円 in April, 2,000円 in February, 0円 elsewhere. */
    @Test
    fun trendEndsWithMonthInView(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            scope.recordExpenseOn(date = "2025-04-15", amount = APRIL_2025, categoryId = food)
            scope.recordExpenseOn(date = "2026-02-15", amount = FEBRUARY_2026, categoryId = food)
            scope.recordExpenseOn(date = "2025-02-15", amount = FEBRUARY_2025, categoryId = food)
            scope.recordIncomeOn(date = "2026-02-15", amount = INCOME)

            val trend = scope.monthlyTrend(to = FIXTURE_FEBRUARY)

            assertEquals(
                expected = TREND_MONTHS.map { month -> YearMonth.parse(month) },
                actual = trend.map { entry -> entry.month },
                message = "2025年3月 から 2026年2月 の 12 か月が順に返らない",
            )
            val expected = mapOf("2025-04" to APRIL_2025, "2026-02" to FEBRUARY_2026)
            assertEquals(
                expected = TREND_MONTHS.map { month -> expected[month] ?: 0L },
                actual = trend.map { entry -> entry.amount },
                message = "2025年4月 が 1,000円、2026年2月 が 2,000円、ほかが 0円 でない",
            )
        }
}

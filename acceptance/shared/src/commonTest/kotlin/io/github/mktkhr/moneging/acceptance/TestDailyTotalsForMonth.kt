package io.github.mktkhr.moneging.acceptance

import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

private const val DAYS_IN_FEBRUARY = 28
private const val THIRD = 3
private const val TENTH = 10
private const val FIRST_ON_THIRD = 1_500L
private const val SECOND_ON_THIRD = 2_500L
private const val ON_TENTH = 800L
private const val INCOME = 5_000L
private const val MARCH_FIRST = 700L
private const val THIRD_TOTAL = 4_000L

/**
 * AC-B-302 — A month reports a total for every day, including zero days.
 *
 * Given 2026-02 (28 days) with 1,500 yen on the 3rd and 2,500 on the 3rd and
 * 800 on the 10th, an income of 5,000 on the 5th, and 700 on 2026-03-01. When
 * the daily totals are read, then 28 entries are returned in order, each
 * carrying its date, the 3rd is 4,000, the 10th is 800, and every other day
 * is 0.
 */
class TestDailyTotalsForMonth {
    /** February's 28 daily totals are in date order: 4,000円 on the 3rd, 800円 on the 10th, 0円 elsewhere. */
    @Test
    fun everyDayOfTheMonthHasATotal(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            scope.recordExpenseOn(date = "2026-02-03", amount = FIRST_ON_THIRD, categoryId = food)
            scope.recordExpenseOn(date = "2026-02-03", amount = SECOND_ON_THIRD, categoryId = food)
            scope.recordExpenseOn(date = "2026-02-10", amount = ON_TENTH, categoryId = food)
            scope.recordIncomeOn(date = "2026-02-05", amount = INCOME)
            scope.recordExpenseOn(date = "2026-03-01", amount = MARCH_FIRST, categoryId = food)

            val totals = scope.dailyTotals(month = FIXTURE_FEBRUARY)

            assertEquals(
                expected = (1..DAYS_IN_FEBRUARY).map { day -> LocalDate(year = 2026, month = 2, day = day) },
                actual = totals.map { entry -> entry.date },
                message = "2月 の 28 日分が日付順に返らない",
            )
            val expected = mapOf(THIRD to THIRD_TOTAL, TENTH to ON_TENTH)
            assertEquals(
                expected = (1..DAYS_IN_FEBRUARY).map { day -> expected[day] ?: 0L },
                actual = totals.map { entry -> entry.amount },
                message = "3日 が 4,000円、10日 が 800円、ほかの日が 0円 でない",
            )
        }
}

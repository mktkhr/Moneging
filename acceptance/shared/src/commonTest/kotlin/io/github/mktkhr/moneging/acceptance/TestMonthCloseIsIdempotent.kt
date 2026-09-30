package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.CarryOverPolicy
import io.github.mktkhr.moneging.domain.SavingsContribution
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

private const val REPEATED_CLOSES = 2

/**
 * AC-B-403 — Closing the same month twice does not double the leftover.
 *
 * Given the state after AC-B-402 with `carry`. When 2026-02 is closed twice
 * more, then each close reports the same as the first and the 2026-03 budget
 * is still 41,500. With `save`, closing 2026-02 again leaves savings at
 * 11,500 in one contribution.
 */
class TestMonthCloseIsIdempotent {
    /** Closing 2026-02 again reports the first close again and moves nothing more. */
    @Test
    fun closingAgainMovesNothingMore(): TestResult =
        runTest {
            val carryClock = ManualClock(current = FIXTURE_NOON)
            val carrying = closableScope(clock = carryClock, policy = CarryOverPolicy.CARRY)
            carryClock.current = BUDGET_MARCH_FIFTH
            val first = carrying.closeMonth(month = BUDGET_FEBRUARY)
            repeat(times = REPEATED_CLOSES) {
                assertEquals(
                    expected = first,
                    actual = carrying.closeMonth(month = BUDGET_FEBRUARY),
                    message = "2月 をもう一度締めても最初と同じ報告にならない",
                )
            }
            val march = carrying.foodBudgetIn(month = BUDGET_MARCH)
            assertEquals(
                expected = BUDGET_FOOD_WITH_CARRY,
                actual = march.budget,
                message = "締め直して 3月 の 食費 が 41,500円 でなくなった",
            )
            assertEquals(expected = BUDGET_LEFTOVER, actual = march.carriedIn, message = "締め直して繰り越した額が 11,500円 でなくなった")

            val saveClock = ManualClock(current = FIXTURE_NOON)
            val saving = closableScope(clock = saveClock, policy = CarryOverPolicy.SAVE)
            saveClock.current = BUDGET_MARCH_FIFTH
            saving.closeMonth(month = BUDGET_FEBRUARY)
            saving.closeMonth(month = BUDGET_FEBRUARY)
            val savings = saving.savings()
            assertEquals(expected = BUDGET_LEFTOVER, actual = savings.balance, message = "締め直して貯金が 11,500円 でなくなった")
            assertEquals(
                expected = listOf(SavingsContribution(month = BUDGET_FEBRUARY, amount = BUDGET_LEFTOVER)),
                actual = savings.contributions,
                message = "締め直して貯金の積み立てが 1 件でなくなった",
            )
        }
}

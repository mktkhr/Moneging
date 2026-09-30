package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import io.github.mktkhr.moneging.domain.SavingsContribution
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlin.uuid.Uuid

/**
 * AC-B-402 — Closing a month carries the leftover over, or moves it to
 * savings.
 *
 * Given the policy `carry`, a 食費 budget of 30,000 from 2026-02, and 18,500
 * 食費 and 3,000 交通費 spent in 2026-02. On 2026-02-15, closing 2026-02 is
 * refused as a conflict (it has not ended). On 2026-03-05, when 2026-02 is
 * closed, then the close reports 11,500 carried into 食費 and nothing saved,
 * the 2026-03 食費 budget is 41,500 with 11,500 carried in, and savings are 0.
 * Given the same state with policy `save`, when 2026-02 is closed, then the
 * 2026-03 食費 budget is 30,000, savings are 11,500, and the contribution is
 * recorded against 2026-02. Afterwards 2026-02 is reported closed, setting a
 * budget in it is refused as a conflict, and closing 2026-03 is refused (it
 * has not ended).
 */
class TestMonthCloseCarryOrSave {
    /** Under `carry` 11,500円 goes into March's 食費; under `save` it goes to savings against 2026-02. */
    @Test
    fun closingCarriesOrSaves(): TestResult =
        runTest {
            closeUnderCarry()
            closeUnderSave()
        }

    // Closes February under `carry` and checks what moved.
    private suspend fun closeUnderCarry() {
        val clock = ManualClock(current = FIXTURE_NOON)
        val scope = closableScope(clock = clock, policy = CarryOverPolicy.CARRY)
        val food = scope.categoryIdNamed(name = "食費")
        assertFailsWith<IllegalStateException>(message = "終わっていない 2月 が締められてしまう") {
            scope.closeMonth(month = BUDGET_FEBRUARY)
        }
        clock.current = BUDGET_MARCH_FIFTH

        val close = scope.closeMonth(month = BUDGET_FEBRUARY)

        assertEquals(
            expected = mapOf(food to BUDGET_LEFTOVER),
            actual = close.carried,
            message = "繰り越しが 食費 11,500円 でない",
        )
        assertEquals(expected = 0L, actual = close.saved, message = "繰り越しなのに貯金に回っている")
        val march = scope.foodBudgetIn(month = BUDGET_MARCH)
        assertEquals(expected = BUDGET_FOOD_WITH_CARRY, actual = march.budget, message = "3月 の 食費 が 41,500円 でない")
        assertEquals(expected = BUDGET_LEFTOVER, actual = march.carriedIn, message = "3月 の 食費 に繰り越された額が 11,500円 でない")
        assertEquals(expected = 0L, actual = scope.savings().balance, message = "繰り越しなのに貯金が 0円 でない")
        assertClosed(scope = scope, food = food)
    }

    // Closes February under `save` and checks what moved.
    private suspend fun closeUnderSave() {
        val clock = ManualClock(current = FIXTURE_NOON)
        val scope = closableScope(clock = clock, policy = CarryOverPolicy.SAVE)
        val food = scope.categoryIdNamed(name = "食費")
        clock.current = BUDGET_MARCH_FIFTH

        val close = scope.closeMonth(month = BUDGET_FEBRUARY)

        assertEquals(expected = BUDGET_LEFTOVER, actual = close.saved, message = "貯金に回った額が 11,500円 でない")
        assertEquals(expected = emptyMap(), actual = close.carried, message = "貯金なのに繰り越されている")
        val march = scope.foodBudgetIn(month = BUDGET_MARCH)
        assertEquals(expected = BUDGET_FOOD_AMOUNT, actual = march.budget, message = "3月 の 食費 が 30,000円 でない")
        val savings = scope.savings()
        assertEquals(expected = BUDGET_LEFTOVER, actual = savings.balance, message = "貯金が 11,500円 でない")
        assertEquals(
            expected = listOf(SavingsContribution(month = BUDGET_FEBRUARY, amount = BUDGET_LEFTOVER)),
            actual = savings.contributions,
            message = "貯金の積み立てが 2月 の 11,500円 1 件でない",
        )
        assertClosed(scope = scope, food = food)
    }

    // After closing February: it reads closed, takes no budget, and March cannot be closed yet.
    private suspend fun assertClosed(
        scope: LedgerScope,
        food: Uuid,
    ) {
        assertTrue(actual = scope.isMonthClosed(month = BUDGET_FEBRUARY), message = "締めた 2月 が締め済みでない")
        assertFailsWith<IllegalStateException>(message = "締めた 2月 に予算を設定できてしまう") {
            scope.setBudget(categoryId = food, amount = BUDGET_FOOD_WITH_CARRY, from = BUDGET_FEBRUARY)
        }
        assertFailsWith<IllegalStateException>(message = "終わっていない 3月 が締められてしまう") {
            scope.closeMonth(month = BUDGET_MARCH)
        }
    }
}

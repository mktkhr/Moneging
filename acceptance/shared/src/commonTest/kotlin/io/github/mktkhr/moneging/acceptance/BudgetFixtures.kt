package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.BudgetLine
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import kotlinx.datetime.YearMonth
import kotlin.time.Instant

// Fixtures shared by the Budget and savings criteria (AC-B-401 to AC-B-403).

/** The month AC-B-402's budget starts in and that is closed. */
internal val BUDGET_FEBRUARY: YearMonth = YearMonth.parse("2026-02")

/** The month after [BUDGET_FEBRUARY]. */
internal val BUDGET_MARCH: YearMonth = YearMonth.parse("2026-03")

/** 2026-03-05 in Asia/Tokyo: the day February is closed on. */
internal val BUDGET_MARCH_FIFTH: Instant = Instant.parse("2026-03-05T12:00:00+09:00")

/** The 食費 budget of 30,000 yen from 2026-02. */
internal const val BUDGET_FOOD_AMOUNT = 30_000L

/** The 食費 spent in 2026-02. */
internal const val BUDGET_FOOD_SPENT = 18_500L

/** The 交通費 spent in 2026-02. */
internal const val BUDGET_TRANSPORT_SPENT = 3_000L

/** What is left of the 食費 budget after February. */
internal const val BUDGET_LEFTOVER = 11_500L

/** The 食費 budget of March when February's leftover is carried in. */
internal const val BUDGET_FOOD_WITH_CARRY = 41_500L

/**
 * A ledger `家計` on [clock] (2026-02-15) with [policy], a 食費 budget of
 * 30,000 from 2026-02, and 18,500 食費 and 3,000 交通費 spent in 2026-02.
 */
internal suspend fun closableScope(
    clock: ManualClock,
    policy: CarryOverPolicy,
): LedgerScope {
    val scope = kakeiScope(clock = clock)
    val food = scope.categoryIdNamed(name = "食費")
    val transport = scope.categoryIdNamed(name = "交通費")
    scope.setCarryOverPolicy(policy = policy)
    scope.setBudget(categoryId = food, amount = BUDGET_FOOD_AMOUNT, from = BUDGET_FEBRUARY)
    scope.recordExpenseOn(date = "2026-02-10", amount = BUDGET_FOOD_SPENT, categoryId = food)
    scope.recordExpenseOn(date = "2026-02-12", amount = BUDGET_TRANSPORT_SPENT, categoryId = transport)
    return scope
}

/** The line of 食費 in the budget view of [month]. */
internal suspend fun LedgerScope.foodBudgetIn(month: YearMonth): BudgetLine {
    val food = categoryIdNamed(name = "食費")
    return budgetRemaining(month = month).categories.single { line -> line.categoryId == food }
}

package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.uuid.Uuid

private const val FOOD_BUDGET = 30_000L
private const val FOOD_PLAIN = 10_000L
private const val SPLIT_TOTAL = 9_000L
private const val SPLIT_FOOD = 8_500L
private const val SPLIT_DAILY = 500L
private const val TRANSPORT = 3_000L
private const val INCOME = 5_000L
private const val MARCH_FOOD = 700L
private const val FEBRUARY_FOOD_SPENT = 18_500L
private const val FEBRUARY_FOOD_REMAINING = 11_500L
private const val MARCH_FOOD_REMAINING = 29_300L

/**
 * AC-B-401 — A monthly budget per category reports how much is left.
 *
 * Given a 食費 budget of 30,000 from 2026-02 and spending in 2026-02 of
 * 10,000 食費, 9,000 split into 8,500 食費 and 500 日用品, and 3,000 交通費, an
 * income of 5,000, and 700 食費 on 2026-03-01. When remaining is read for
 * 2026-02, then 食費 shows a budget of 30,000, spent 18,500 and remaining
 * 11,500, 日用品 shows no budget and spent 500, and 交通費 shows no budget and
 * spent 3,000, in category order. When it is read for 2026-03, then 食費 still
 * has a budget of 30,000, spent 700 and remaining 29,300.
 */
class TestBudgetRemaining {
    /** February reads 食費 30,000円 budget, 18,500円 spent, 11,500円 left; March 700円 spent, 29,300円 left. */
    @Test
    fun budgetReportsHowMuchIsLeft(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val daily = scope.categoryIdNamed(name = "日用品")
            val transport = scope.categoryIdNamed(name = "交通費")
            scope.setBudget(categoryId = food, amount = FOOD_BUDGET, from = BUDGET_FEBRUARY)
            scope.recordSpending(food = food, daily = daily, transport = transport)

            val february = scope.budgetRemaining(month = BUDGET_FEBRUARY).categories
            assertEquals(
                expected = listOf(food, daily, transport),
                actual = february.map { line -> line.categoryId },
                message = "2月 の予算の分類が 食費・日用品・交通費 の順でない",
            )
            assertEquals(
                expected = listOf(FOOD_BUDGET, null, null),
                actual = february.map { line -> line.budget },
                message = "2月 の予算が 食費 30,000円、日用品・交通費 は予算なし でない",
            )
            assertEquals(
                expected = listOf(FEBRUARY_FOOD_SPENT, SPLIT_DAILY, TRANSPORT),
                actual = february.map { line -> line.spent },
                message = "2月 の支出が 食費 18,500円・日用品 500円・交通費 3,000円 でない",
            )
            assertEquals(
                expected = FEBRUARY_FOOD_REMAINING,
                actual = february.first().remaining,
                message = "2月 の 食費 の残りが 11,500円 でない",
            )
            assertNull(actual = february[1].remaining, message = "予算のない 日用品 に残りがある")

            val march = scope.budgetRemaining(month = BUDGET_MARCH).categories.single()
            assertEquals(expected = food, actual = march.categoryId, message = "3月 に 食費 だけが並ばない")
            assertEquals(expected = FOOD_BUDGET, actual = march.budget, message = "3月 の 食費 の予算が 30,000円 でない")
            assertEquals(expected = MARCH_FOOD, actual = march.spent, message = "3月 の 食費 の支出が 700円 でない")
            assertEquals(
                expected = MARCH_FOOD_REMAINING,
                actual = march.remaining,
                message = "3月 の 食費 の残りが 29,300円 でない",
            )
        }

    // Records the criterion's spending: February's 食費 (plain and split), 交通費, an income, and March's 食費.
    private suspend fun LedgerScope.recordSpending(
        food: Uuid,
        daily: Uuid,
        transport: Uuid,
    ) {
        recordExpenseOn(date = "2026-02-03", amount = FOOD_PLAIN, categoryId = food)
        recordTransaction(
            transaction =
                NewTransaction(
                    date = LocalDate.parse("2026-02-09"),
                    direction = Direction.EXPENSE,
                    amount = SPLIT_TOTAL,
                    categoryId = null,
                    items =
                        listOf(
                            NewLineItem(amount = SPLIT_FOOD, categoryId = food),
                            NewLineItem(amount = SPLIT_DAILY, categoryId = daily),
                        ),
                ),
        )
        recordExpenseOn(date = "2026-02-11", amount = TRANSPORT, categoryId = transport)
        recordIncomeOn(date = "2026-02-12", amount = INCOME)
        recordExpenseOn(date = "2026-03-01", amount = MARCH_FOOD, categoryId = food)
    }
}

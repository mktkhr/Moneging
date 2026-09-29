package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

private const val FOOD_FIRST = 1_000L
private const val FOOD_SECOND = 2_000L
private const val TRANSPORT = 3_000L
private const val SPLIT_TOTAL = 3_000L
private const val SPLIT_FOOD = 1_200L
private const val SPLIT_DAILY = 1_800L
private const val INCOME = 5_000L
private const val JANUARY_FOOD = 500L
private const val MARCH_FOOD = 700L
private const val FOOD_TOTAL = 4_200L
private const val EXPENSE_TOTAL = 9_000L

/**
 * AC-B-301 — A month reports totals by category.
 *
 * Given 2026-02 with 1,000 and 2,000 食費, 3,000 交通費, an expense of 3,000
 * split into 1,200 食費 and 1,800 日用品, an income of 5,000, and 500 食費 on
 * 2026-01-31 and 700 食費 on 2026-03-01. When the monthly report is read,
 * then it lists 食費 4,200, 交通費 3,000 and 日用品 1,800 in that order
 * (largest first), the expense total is 9,000, and income is not counted in
 * any category.
 */
class TestMonthlyReport {
    /** February's report lists 食費 4,200円, 交通費 3,000円 and 日用品 1,800円, totalling 9,000円. */
    @Test
    fun monthReportsTotalsByCategory(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val transport = scope.categoryIdNamed(name = "交通費")
            val daily = scope.categoryIdNamed(name = "日用品")
            scope.recordExpenseOn(date = "2026-02-03", amount = FOOD_FIRST, categoryId = food)
            scope.recordExpenseOn(date = "2026-02-05", amount = FOOD_SECOND, categoryId = food)
            scope.recordExpenseOn(date = "2026-02-07", amount = TRANSPORT, categoryId = transport)
            scope.recordTransaction(
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
            scope.recordIncomeOn(date = "2026-02-10", amount = INCOME)
            scope.recordExpenseOn(date = "2026-01-31", amount = JANUARY_FOOD, categoryId = food)
            scope.recordExpenseOn(date = "2026-03-01", amount = MARCH_FOOD, categoryId = food)

            val report = scope.monthlyReport(month = FIXTURE_FEBRUARY)

            assertEquals(
                expected = listOf(food to FOOD_TOTAL, transport to TRANSPORT, daily to SPLIT_DAILY),
                actual = report.categories.map { entry -> entry.categoryId to entry.amount },
                message = "2月 の分類別が 食費 4,200円・交通費 3,000円・日用品 1,800円 の大きい順でない",
            )
            assertEquals(expected = EXPENSE_TOTAL, actual = report.expenseTotal, message = "2月 の支出が 9,000円 でない")
        }
}

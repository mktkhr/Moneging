package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

private const val FIRST_EXPENSE = 1_000L
private const val SECOND_EXPENSE = 2_000L
private const val INCOME = 5_000L
private const val EXPECTED_EXPENSE = 3_000L
private const val EXPECTED_BALANCE = 2_000L

/**
 * AC-B-205 — Income is recorded and the month's balance is income minus
 * expense.
 *
 * Given 2026-02 with expenses 1,000 and 2,000 and an income of 5,000. When
 * the month's summary is read, then income is 5,000, expense is 3,000 and the
 * balance is 2,000.
 */
class TestMonthlyBalance {
    /** February's summary reads income 5,000円, expense 3,000円 and balance 2,000円. */
    @Test
    fun balanceIsIncomeMinusExpense(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val date = LocalDate.parse("2026-02-10")
            for (amount in listOf(FIRST_EXPENSE, SECOND_EXPENSE)) {
                scope.recordTransaction(
                    transaction =
                        NewTransaction(date = date, direction = Direction.EXPENSE, amount = amount, categoryId = food),
                )
            }
            val income =
                scope.recordTransaction(
                    transaction =
                        NewTransaction(date = date, direction = Direction.INCOME, amount = INCOME, categoryId = null),
                )
            assertEquals(expected = Direction.INCOME, actual = scope.findTransaction(id = income.id)?.direction)

            val summary = scope.monthTotals(month = FIXTURE_FEBRUARY)

            assertEquals(expected = INCOME, actual = summary.income, message = "2月 の収入が 5,000円 でない")
            assertEquals(expected = EXPECTED_EXPENSE, actual = summary.expense, message = "2月 の支出が 3,000円 でない")
            assertEquals(expected = EXPECTED_BALANCE, actual = summary.balance, message = "2月 の収支が 2,000円 でない")
        }
}

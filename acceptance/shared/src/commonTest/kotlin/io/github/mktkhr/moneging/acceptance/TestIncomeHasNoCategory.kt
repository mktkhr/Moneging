package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

private const val INCOME_AMOUNT = 5_000L

/**
 * AC-B-210 — Income carries no category.
 *
 * Given the ledger `家計`. When an income of 5,000 yen is recorded, then it
 * reads back with no category. When an income is recorded with the category
 * 食費, then it is refused as invalid. When an expense is recorded with no
 * category and no items, then it is refused as invalid.
 */
class TestIncomeHasNoCategory {
    /** Income is recorded without a category, and refused with one; an expense is refused without one. */
    @Test
    fun incomeCarriesNoCategory(): TestResult =
        runTest {
            val scope = kakeiScope()
            val date = LocalDate.parse("2026-02-15")

            val income =
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.INCOME,
                            amount = INCOME_AMOUNT,
                            categoryId = null,
                        ),
                )
            val read = scope.findTransaction(id = income.id)
            assertEquals(expected = income, actual = read)
            assertEquals(expected = Direction.INCOME, actual = read?.direction)
            assertEquals(expected = INCOME_AMOUNT, actual = read?.amount, message = "収入が 5,000円 と読み戻せない")
            assertNull(actual = read?.categoryId, message = "収入に分類が付いている")
            assertEquals(expected = emptyList(), actual = read?.items, message = "収入に明細が付いている")

            assertFailsWith<IllegalArgumentException>(message = "分類 食費 の付いた収入が記録できてしまう") {
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.INCOME,
                            amount = INCOME_AMOUNT,
                            categoryId = scope.categoryIdNamed(name = "食費"),
                        ),
                )
            }
            assertFailsWith<IllegalArgumentException>(message = "分類も明細もない支出が記録できてしまう") {
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = INCOME_AMOUNT,
                            categoryId = null,
                        ),
                )
            }

            assertEquals(
                expected = listOf(income.id),
                actual = scope.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.id },
                message = "拒否された記録が残った",
            )
        }
}

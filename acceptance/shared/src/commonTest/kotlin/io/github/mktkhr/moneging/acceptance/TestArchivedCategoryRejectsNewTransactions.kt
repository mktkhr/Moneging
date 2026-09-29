package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

private const val ENTERTAINMENT_AMOUNT = 2_500L

/**
 * AC-B-207 — An archived category keeps its history and takes no new
 * transactions.
 *
 * Given the category 娯楽 with one transaction of 2,500 yen. When 娯楽 is
 * archived, then the transaction still reads back with category 娯楽 and is
 * counted in 2026-02's expense total, and creating a new transaction with 娯楽
 * is refused as invalid.
 */
class TestArchivedCategoryRejectsNewTransactions {
    /** Archiving 娯楽 keeps its 2,500円 in February and refuses a new transaction in it. */
    @Test
    fun keepsHistoryRefusesNew(): TestResult =
        runTest {
            val scope = kakeiScope()
            val entertainment = scope.categoryIdNamed(name = "娯楽")
            val date = LocalDate.parse("2026-02-10")
            val kept =
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = ENTERTAINMENT_AMOUNT,
                            categoryId = entertainment,
                        ),
                )

            val archived = scope.archiveCategory(categoryId = entertainment)

            assertEquals(expected = true, actual = archived.isArchived, message = "娯楽 がアーカイブされない")
            assertEquals(expected = "娯楽", actual = archived.name)
            assertEquals(
                expected = archived,
                actual = scope.findCategory(id = entertainment),
                message = "アーカイブした 娯楽 が読めない",
            )
            val read = scope.findTransaction(id = kept.id)
            assertEquals(expected = entertainment, actual = read?.categoryId, message = "アーカイブ後、取引の分類が 娯楽 でない")
            assertEquals(
                expected = "娯楽",
                actual = read?.categoryId?.let { id -> scope.findCategory(id = id)?.name },
            )
            assertEquals(expected = ENTERTAINMENT_AMOUNT, actual = read?.amount)
            assertEquals(
                expected = ENTERTAINMENT_AMOUNT,
                actual = scope.monthTotals(month = FIXTURE_FEBRUARY).expense,
                message = "アーカイブした 娯楽 の 2,500円 が 2月 の支出に数えられない",
            )

            assertFailsWith<IllegalArgumentException>(message = "アーカイブした 娯楽 で新しく記録できてしまう") {
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = ENTERTAINMENT_AMOUNT,
                            categoryId = entertainment,
                        ),
                )
            }
            assertEquals(
                expected = listOf(kept.id),
                actual = scope.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.id },
                message = "拒否された記録が残った",
            )
        }
}

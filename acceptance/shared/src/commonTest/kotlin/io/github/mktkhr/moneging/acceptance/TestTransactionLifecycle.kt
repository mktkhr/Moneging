package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.uuid.Uuid

/**
 * AC-B-201 — A transaction is created, read, updated and deleted.
 *
 * Given the category 食費. When an expense of 1,200 yen on 2026-02-10 with
 * memo `ランチ` is created, then it has an id and reads back with that date,
 * direction, amount, category and memo. When its amount is changed to 1,500
 * and its memo to `外食`, then it reads back changed and its date and
 * category are unchanged. When it is deleted, then reading it finds nothing.
 */
class TestTransactionLifecycle {
    /** An expense is created, read back, changed (amount and memo only) and deleted. */
    @Test
    fun createsReadsUpdatesAndDeletes(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val date = LocalDate.parse("2026-02-10")

            val created =
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = 1_200L,
                            categoryId = food,
                            memo = "ランチ",
                        ),
                )
            assertNotEquals(illegal = Uuid.NIL, actual = created.id, message = "作成した取引に識別子がない")
            val read = scope.findTransaction(id = created.id)
            assertEquals(expected = created, actual = read, message = "作成した取引が読み戻せない")
            assertEquals(expected = date, actual = read?.date)
            assertEquals(expected = Direction.EXPENSE, actual = read?.direction)
            assertEquals(expected = 1_200L, actual = read?.amount)
            assertEquals(expected = food, actual = read?.categoryId)
            assertEquals(expected = "ランチ", actual = read?.memo)

            val updated =
                scope.updateTransaction(
                    transactionId = created.id,
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = 1_500L,
                            categoryId = food,
                            memo = "外食",
                        ),
                )
            val readAfterUpdate = scope.findTransaction(id = created.id)
            assertEquals(expected = updated, actual = readAfterUpdate, message = "変更した取引が読み戻せない")
            assertEquals(expected = created.id, actual = readAfterUpdate?.id, message = "変更で識別子が変わった")
            assertEquals(expected = 1_500L, actual = readAfterUpdate?.amount, message = "金額が 1,500円 に変わらない")
            assertEquals(expected = "外食", actual = readAfterUpdate?.memo, message = "メモが 外食 に変わらない")
            assertEquals(expected = date, actual = readAfterUpdate?.date, message = "変更で日付が変わった")
            assertEquals(expected = food, actual = readAfterUpdate?.categoryId, message = "変更で分類が変わった")
            assertEquals(expected = Direction.EXPENSE, actual = readAfterUpdate?.direction)

            scope.deleteTransaction(transactionId = created.id)

            assertNull(actual = scope.findTransaction(id = created.id), message = "削除した取引が読める")
            assertEquals(
                expected = emptyList(),
                actual = scope.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.id },
                message = "削除した取引が 2月 の一覧に残る",
            )
        }
}

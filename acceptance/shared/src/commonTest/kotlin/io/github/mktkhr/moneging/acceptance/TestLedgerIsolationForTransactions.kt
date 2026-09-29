package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.domain.TransactionQuery
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

private const val T1_AMOUNT = 1_200L
private const val LEDGER_A_AMOUNT = 300L
private const val CHANGED_AMOUNT = 9_999L

/**
 * AC-B-208 — An operation in one ledger cannot read or write another's
 * transactions.
 *
 * Given ledgers `A` and `B`, and a transaction `t1` of 1,200 yen in `B`.
 * When, acting within `A`, transactions are listed, and `t1` is read, updated
 * and deleted by its id, then the list does not hold `t1`, and reading,
 * updating and deleting each find nothing, and `t1` still exists in `B`
 * unchanged.
 *
 * "Find nothing" for a write is a refusal ([IllegalArgumentException]) that
 * changes nothing. `A` holds a transaction of its own (300円), so its list is
 * compared against a non-empty month.
 */
class TestLedgerIsolationForTransactions {
    /** Within `A`, `t1` of `B` is neither listed, searched, read, updated nor deleted, and stays as it was in `B`. */
    @Test
    fun isolatesTransactions(): TestResult =
        runTest {
            val store = LocalStore.inMemory(clock = ManualClock(current = FIXTURE_NOON), deviceId = FIXTURE_DEVICE_ID)
            val scopeA = store.ledger(id = store.createLedger(name = "A").id)
            val scopeB = store.ledger(id = store.createLedger(name = "B").id)
            val date = LocalDate.parse("2026-02-10")
            val t1 =
                scopeB.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = T1_AMOUNT,
                            categoryId = scopeB.categoryIdNamed(name = "食費"),
                        ),
                )
            val foodOfA = scopeA.categoryIdNamed(name = "食費")
            val ownOfA =
                scopeA.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = LEDGER_A_AMOUNT,
                            categoryId = foodOfA,
                        ),
                )

            assertAHoldsOnlyItsOwn(scopeA = scopeA, ownOfA = ownOfA, message = "A の一覧か検索に B の t1 がある")
            assertNull(actual = scopeA.findTransaction(id = t1.id), message = "A から B の t1 が読める")
            assertFailsWith<IllegalArgumentException>(message = "A から B の t1 を変更できてしまう") {
                scopeA.updateTransaction(
                    transactionId = t1.id,
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = CHANGED_AMOUNT,
                            categoryId = foodOfA,
                        ),
                )
            }
            assertFailsWith<IllegalArgumentException>(message = "A から B の t1 を削除できてしまう") {
                scopeA.deleteTransaction(transactionId = t1.id)
            }

            assertEquals(expected = t1, actual = scopeB.findTransaction(id = t1.id), message = "B の t1 が変わった")
            assertEquals(expected = T1_AMOUNT, actual = scopeB.findTransaction(id = t1.id)?.amount)
            assertEquals(
                expected = listOf(t1.id),
                actual = scopeB.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.id },
                message = "B の一覧に t1 だけが残っていない",
            )
            assertAHoldsOnlyItsOwn(scopeA = scopeA, ownOfA = ownOfA, message = "拒否された書き込みで A の一覧が変わった")
        }
}

// Within A, the month's list and a search over 2026 hold exactly A's own transaction.
internal suspend fun assertAHoldsOnlyItsOwn(
    scopeA: LedgerScope,
    ownOfA: Transaction,
    message: String,
) {
    assertEquals(
        expected = listOf(ownOfA.id),
        actual = scopeA.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.id },
        message = message,
    )
    val searched =
        scopeA.searchTransactions(
            query = TransactionQuery(from = LocalDate.parse("2026-01-01"), to = LocalDate.parse("2026-12-31")),
        )
    assertEquals(expected = listOf(ownOfA.id), actual = searched.map { found -> found.id }, message = message)
}

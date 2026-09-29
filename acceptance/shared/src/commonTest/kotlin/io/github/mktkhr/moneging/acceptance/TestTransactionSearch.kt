package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.TransactionQuery
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.uuid.Uuid

private const val SUPERMARKET_AMOUNT = 1_000L
private const val EATING_OUT_AMOUNT = 2_000L
private const val TRAIN_AMOUNT = 3_000L
private const val JANUARY_AMOUNT = 4_000L

/**
 * AC-B-204 — Transactions are searched by period, category and text.
 *
 * Given three expenses in 2026-02: 1,000 食費 memo `スーパー`, 2,000 食費
 * memo `外食` and 3,000 交通費 memo `電車`; and 4,000 食費 in 2026-01. When
 * searched by period 2026-02-01..2026-02-28, then three are returned. When
 * also by category 食費, then two. When also by text `外`, then one, of 2,000.
 * When searched by amount 2,000..3,000 in that period, then two.
 *
 * Periods and amount ranges include both ends. The order of the results is not part of the criterion, so the
 * amounts are compared sorted.
 */
class TestTransactionSearch {
    /** Each added condition narrows the results: period, then category, then text; and an amount range. */
    @Test
    fun searchesByEachCondition(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val transport = scope.categoryIdNamed(name = "交通費")
            recordSearchFixtures(scope = scope, food = food, transport = transport)
            val from = LocalDate.parse("2026-02-01")
            val to = LocalDate.parse("2026-02-28")

            assertEquals(
                expected = listOf(SUPERMARKET_AMOUNT, EATING_OUT_AMOUNT, TRAIN_AMOUNT),
                actual = scope.searchedAmounts(query = TransactionQuery(from = from, to = to)),
                message = "期間 2月1日〜2月28日 で 3 件にならない",
            )
            assertEquals(
                expected = listOf(SUPERMARKET_AMOUNT, EATING_OUT_AMOUNT),
                actual = scope.searchedAmounts(query = TransactionQuery(from = from, to = to, categoryId = food)),
                message = "期間と分類 食費 で 2 件にならない",
            )
            assertEquals(
                expected = listOf(EATING_OUT_AMOUNT),
                actual =
                    scope.searchedAmounts(
                        query = TransactionQuery(from = from, to = to, categoryId = food, text = "外"),
                    ),
                message = "期間と分類 食費 と文字 外 で 2,000円 の 1 件にならない",
            )
            assertEquals(
                expected = listOf(EATING_OUT_AMOUNT, TRAIN_AMOUNT),
                actual =
                    scope.searchedAmounts(
                        query =
                            TransactionQuery(
                                from = from,
                                to = to,
                                minAmount = EATING_OUT_AMOUNT,
                                maxAmount = TRAIN_AMOUNT,
                            ),
                    ),
                message = "期間と金額 2,000〜3,000円 で 2 件にならない",
            )
        }
}

// The four expenses of AC-B-204: three in 2026-02 and 4,000円 食費 in 2026-01.
internal suspend fun recordSearchFixtures(
    scope: LedgerScope,
    food: Uuid,
    transport: Uuid,
) {
    val expenses =
        listOf(
            NewTransaction(
                date = LocalDate.parse("2026-02-03"),
                direction = Direction.EXPENSE,
                amount = SUPERMARKET_AMOUNT,
                categoryId = food,
                memo = "スーパー",
            ),
            NewTransaction(
                date = LocalDate.parse("2026-02-10"),
                direction = Direction.EXPENSE,
                amount = EATING_OUT_AMOUNT,
                categoryId = food,
                memo = "外食",
            ),
            NewTransaction(
                date = LocalDate.parse("2026-02-20"),
                direction = Direction.EXPENSE,
                amount = TRAIN_AMOUNT,
                categoryId = transport,
                memo = "電車",
            ),
            NewTransaction(
                date = LocalDate.parse("2026-01-20"),
                direction = Direction.EXPENSE,
                amount = JANUARY_AMOUNT,
                categoryId = food,
            ),
        )
    expenses.forEach { expense -> scope.recordTransaction(transaction = expense) }
}

// The amounts of the transactions [query] finds, sorted.
internal suspend fun LedgerScope.searchedAmounts(query: TransactionQuery): List<Long> =
    searchTransactions(query = query).map { found -> found.amount }.sorted()

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
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.uuid.Uuid

private const val FOOD_ITEM_AMOUNT = 1_200L
private const val DAILY_ITEM_AMOUNT = 1_800L
private const val DAILY_ITEM_CHANGED = 1_900L
private const val TOTAL = 3_000L
private const val TOTAL_CHANGED = 3_100L

/**
 * AC-B-203 — A transaction split into line items has items summing to its
 * amount.
 *
 * Given a transaction of 3,000 yen with items 1,200 (食費) and 1,800 (日用品).
 * When it is read, then its amount is 3,000 and it has two items. When the
 * 日用品 item is changed to 1,900, then the change is refused and the
 * transaction still totals 3,000 with its original items. When it is changed
 * to 1,900 together with the total 3,100, then both change
 * (1,200 + 1,900 = 3,100).
 */
class TestLineItemsSumToTotal {
    /** A change that leaves the items not adding up to the amount is refused; one that keeps them equal is taken. */
    @Test
    fun itemsSumToTheAmount(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val daily = scope.categoryIdNamed(name = "日用品")
            val created =
                scope.recordTransaction(
                    transaction =
                        splitExpense(
                            food = food,
                            daily = daily,
                            dailyAmount = DAILY_ITEM_AMOUNT,
                            total = TOTAL,
                        ),
                )

            val read = assertNotNull(actual = scope.findTransaction(id = created.id), message = "作成した取引が読めない")
            assertEquals(expected = TOTAL, actual = read.amount, message = "分けた取引の金額が 3,000円 でない")
            assertEquals(
                expected = listOf(FOOD_ITEM_AMOUNT to food, DAILY_ITEM_AMOUNT to daily),
                actual = read.items.map { item -> item.amount to item.categoryId },
                message = "明細が 1,200円 食費 と 1,800円 日用品 の 2 件でない",
            )

            assertFailsWith<IllegalArgumentException>(message = "明細の合計 3,100円 と金額 3,000円 が合わない変更ができてしまう") {
                scope.updateTransaction(
                    transactionId = created.id,
                    transaction =
                        splitExpense(food = food, daily = daily, dailyAmount = DAILY_ITEM_CHANGED, total = TOTAL),
                )
            }
            assertEquals(
                expected = created,
                actual = scope.findTransaction(id = created.id),
                message = "拒否された変更で取引か明細が変わった",
            )

            val changed =
                scope.updateTransaction(
                    transactionId = created.id,
                    transaction =
                        splitExpense(
                            food = food,
                            daily = daily,
                            dailyAmount = DAILY_ITEM_CHANGED,
                            total = TOTAL_CHANGED,
                        ),
                )
            assertChangedTogether(scope = scope, transactionId = created.id, food = food, daily = daily)
            assertEquals(expected = changed, actual = scope.findTransaction(id = created.id))
        }
}

// The expense of `total` split into 1,200円 食費 and `dailyAmount` 日用品, on 2026-02-15.
internal fun splitExpense(
    food: Uuid,
    daily: Uuid,
    dailyAmount: Long,
    total: Long,
): NewTransaction =
    NewTransaction(
        date = LocalDate.parse("2026-02-15"),
        direction = Direction.EXPENSE,
        amount = total,
        categoryId = null,
        items =
            listOf(
                NewLineItem(amount = FOOD_ITEM_AMOUNT, categoryId = food),
                NewLineItem(amount = dailyAmount, categoryId = daily),
            ),
    )

// The transaction now totals 3,100円 with items 1,200円 食費 and 1,900円 日用品.
internal suspend fun assertChangedTogether(
    scope: LedgerScope,
    transactionId: Uuid,
    food: Uuid,
    daily: Uuid,
) {
    val read = assertNotNull(actual = scope.findTransaction(id = transactionId), message = "変更した取引が読めない")
    assertEquals(expected = TOTAL_CHANGED, actual = read.amount, message = "金額が 3,100円 に変わらない")
    assertEquals(
        expected = listOf(FOOD_ITEM_AMOUNT to food, DAILY_ITEM_CHANGED to daily),
        actual = read.items.map { item -> item.amount to item.categoryId },
        message = "明細が 1,200円 食費 と 1,900円 日用品 に変わらない",
    )
    assertEquals(
        expected = TOTAL_CHANGED,
        actual = read.items.sumOf { item -> item.amount },
        message = "明細の合計が金額と一致しない",
    )
}

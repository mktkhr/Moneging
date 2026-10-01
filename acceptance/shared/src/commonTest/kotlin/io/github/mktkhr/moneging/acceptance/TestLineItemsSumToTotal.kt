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
private const val SET_JAGA = 1_060L
private const val SET_CHEESE = 1_170L
private const val FRIES = 440L
private const val DISCOUNT = -250L
private const val RECEIPT_TOTAL = 2_420L
private const val DISCOUNTED_ITEM = 250L
private const val DISCOUNT_NAME = "ディスカウント"
private const val SPLIT_DATE = "2026-02-15"

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
 *
 * Given a transaction in 2026-02 of 2,420 yen with items 1,060, 1,170 and 440
 * (食費) and a discount item `ディスカウント` of −250 (食費), when it is read,
 * then it has four items, the discount −250, and 2026-02's report counts 2,420
 * in 食費. A transaction whose only item is a discount, or whose items add up to
 * less than 1 yen, is refused as invalid.
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

    /** A discount item of −250円 counts against 食費; one alone, or items below 1円, are refused. */
    @Test
    fun discountItemCountsInCategory(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val created = scope.recordTransaction(transaction = discountedReceipt(food = food))

            val read = assertNotNull(actual = scope.findTransaction(id = created.id), message = "割引のある取引が読めない")
            assertEquals(expected = RECEIPT_TOTAL, actual = read.amount, message = "割引のある取引の金額が 2,420円 でない")
            assertEquals(
                expected =
                    listOf(
                        Triple(SET_JAGA, food, null),
                        Triple(SET_CHEESE, food, null),
                        Triple(FRIES, food, null),
                        Triple(DISCOUNT, food, DISCOUNT_NAME),
                    ),
                actual = read.items.map { item -> Triple(item.amount, item.categoryId, item.name) },
                message = "明細が 1,060円・1,170円・440円 と 割引 ディスカウント −250円 の 4 件（すべて食費）でない",
            )

            val report = scope.monthlyReport(month = FIXTURE_FEBRUARY)
            assertEquals(
                expected = listOf(food to RECEIPT_TOTAL),
                actual = report.categories.map { entry -> entry.categoryId to entry.amount },
                message = "2月 の分類別が 食費 2,420円 だけでない（割引が食費から引かれていない）",
            )
            assertEquals(expected = RECEIPT_TOTAL, actual = report.expenseTotal, message = "2月 の支出が 2,420円 でない")

            assertDiscountsRefused(scope = scope, food = food)
            assertEquals(
                expected = listOf(created.id),
                actual = scope.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.id },
                message = "拒否された割引の取引が残った",
            )
        }
}

// The 2,420円 expense of 2026-02-15: 1,060円, 1,170円 and 440円 食費, and the discount ディスカウント −250円 食費.
internal fun discountedReceipt(food: Uuid): NewTransaction =
    NewTransaction(
        date = LocalDate.parse(SPLIT_DATE),
        direction = Direction.EXPENSE,
        amount = RECEIPT_TOTAL,
        categoryId = null,
        items =
            listOf(
                NewLineItem(amount = SET_JAGA, categoryId = food),
                NewLineItem(amount = SET_CHEESE, categoryId = food),
                NewLineItem(amount = FRIES, categoryId = food),
                NewLineItem(amount = DISCOUNT, categoryId = food, name = DISCOUNT_NAME),
            ),
    )

// A transaction whose only item is the discount −250円, and one whose items 250円 and −250円 add up to 0円,
// are each refused as invalid.
internal suspend fun assertDiscountsRefused(
    scope: LedgerScope,
    food: Uuid,
) {
    val discount = NewLineItem(amount = DISCOUNT, categoryId = food, name = DISCOUNT_NAME)
    assertFailsWith<IllegalArgumentException>(message = "割引 −250円 だけの取引が記録できてしまう") {
        scope.recordTransaction(transaction = expenseSplitInto(items = listOf(discount), amount = DISCOUNT))
    }
    assertFailsWith<IllegalArgumentException>(message = "明細の和が 0円 の取引が記録できてしまう") {
        scope.recordTransaction(
            transaction =
                expenseSplitInto(
                    items = listOf(NewLineItem(amount = DISCOUNTED_ITEM, categoryId = food), discount),
                    amount = DISCOUNTED_ITEM + DISCOUNT,
                ),
        )
    }
}

// The expense of 2026-02-15 of `amount` split into `items`.
private fun expenseSplitInto(
    items: List<NewLineItem>,
    amount: Long,
): NewTransaction =
    NewTransaction(
        date = LocalDate.parse(SPLIT_DATE),
        direction = Direction.EXPENSE,
        amount = amount,
        categoryId = null,
        items = items,
    )

// The expense of `total` split into 1,200円 食費 and `dailyAmount` 日用品, on 2026-02-15.
internal fun splitExpense(
    food: Uuid,
    daily: Uuid,
    dailyAmount: Long,
    total: Long,
): NewTransaction =
    NewTransaction(
        date = LocalDate.parse(SPLIT_DATE),
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

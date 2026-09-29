package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Budget
import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.Ledger
import io.github.mktkhr.moneging.domain.MonthTotals
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewRecurringRule
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.SyncRecord
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.uuid.Uuid

private const val CREATED_CATEGORY_NAME = "ペット"
private const val FIRST_ITEM_NAME = "お弁当"
private const val SECOND_ITEM_NAME = "洗剤"
private const val MEMO_BEFORE = "スーパー"
private const val MEMO_AFTER = "スーパーでまとめ買い"
private const val FIRST_ITEM_AMOUNT = 1_200L
private const val SECOND_ITEM_AMOUNT = 500L
private const val SPLIT_AMOUNT = FIRST_ITEM_AMOUNT + SECOND_ITEM_AMOUNT
private const val OTHER_EXPENSE_AMOUNT = 300L
private const val BUDGET_AMOUNT = 5_000L
private const val RENT_AMOUNT = 80_000L
private const val RENT_DAY = 25

// The month and the day every record of this test falls in: the fixtures' 2026-02-15.
private val FIXTURE_MONTH: YearMonth = YearMonth.parse("2026-02")
private val FIXTURE_DATE: LocalDate = LocalDate.parse("2026-02-15")

/**
 * AC-B-108 — Every record carries a UUID and its instants, and a deletion
 * leaves a tombstone.
 *
 * Given the clock at 2026-02-15 12:00 and the device identifier `D`. When a
 * ledger, a category, a transaction with two line items, a budget and a
 * recurring rule are created, then each has a UUID identifier and created and
 * updated instants of 12:00, and the transaction records the device `D`.
 * When the clock moves to 12:05 and the transaction's memo is changed, then
 * its updated instant is 12:05 and its created instant still 12:00. When it is
 * deleted, then it is neither found nor listed nor counted in any total, and
 * the database still holds it, with its items, as a tombstone deleted at
 * 12:05.
 *
 * A second expense (300円, never deleted) is recorded alongside, so that
 * "not listed / not counted" is asserted against a non-empty month.
 */
class TestRecordsAreSyncReady {
    /** Records carry UUIDs and their instants; a deleted transaction becomes a hidden tombstone. */
    @Test
    fun recordsAreSyncReady(): TestResult =
        runTest {
            val clock = ManualClock(current = FIXTURE_NOON)
            val store = LocalStore.inMemory(clock = clock, deviceId = FIXTURE_DEVICE_ID)
            val created = createEveryKindOfRecord(store = store)
            assertCreatedAtNoonOnDeviceD(created = created)
            val scope = store.ledger(id = created.ledger.id)
            assertEquals(
                expected = MonthTotals(expense = SPLIT_AMOUNT + OTHER_EXPENSE_AMOUNT, income = 0L),
                actual = scope.monthTotals(month = FIXTURE_MONTH),
                message = "削除前の月の合計が 1,700円 + 300円 でない",
            )

            clock.current = FIXTURE_NOON_PLUS_FIVE
            val edited = scope.updateMemo(transactionId = created.transaction.id, memo = MEMO_AFTER)
            assertEquals(expected = MEMO_AFTER, actual = edited.memo)
            assertEquals(expected = FIXTURE_NOON_PLUS_FIVE, actual = edited.updatedAt, message = "更新時刻が 12:05 でない")
            assertEquals(expected = FIXTURE_NOON, actual = edited.createdAt, message = "作成時刻が 12:00 のままでない")
            assertEquals(expected = edited, actual = scope.findTransaction(id = created.transaction.id))

            scope.deleteTransaction(transactionId = created.transaction.id)

            assertDeletedIsHidden(scope = scope, created = created)
            assertTombstoneIsHeld(store = store, created = created)
        }
}

// The records AC-B-108 creates at 12:00, plus the never-deleted second expense.
internal data class CreatedRecords(
    val ledger: Ledger,
    val category: Category,
    val transaction: Transaction,
    val otherExpense: Transaction,
    val budget: Budget,
    val recurringRule: RecurringRule,
)

// Creates a ledger, a category, a transaction with two line items, a budget and a recurring rule.
internal suspend fun createEveryKindOfRecord(store: LocalStore): CreatedRecords {
    val ledger = store.createLedger(name = FIXTURE_LEDGER_NAME)
    val scope = store.ledger(id = ledger.id)
    val category = scope.createCategory(name = CREATED_CATEGORY_NAME)
    val categories = scope.categories()
    val transaction = recordSplitExpense(scope = scope, categories = categories)
    val otherExpense =
        scope.recordTransaction(
            transaction =
                NewTransaction(
                    date = FIXTURE_DATE,
                    direction = Direction.EXPENSE,
                    amount = OTHER_EXPENSE_AMOUNT,
                    categoryId = categories.idOf(name = "その他"),
                ),
        )
    val budget = scope.setBudget(categoryId = category.id, amount = BUDGET_AMOUNT, from = FIXTURE_MONTH)
    val recurringRule =
        scope.createRecurringRule(
            rule =
                NewRecurringRule(
                    direction = Direction.EXPENSE,
                    amount = RENT_AMOUNT,
                    categoryId = categories.idOf(name = "住居"),
                    dayOfMonth = RENT_DAY,
                    startMonth = FIXTURE_MONTH,
                    endMonth = null,
                ),
        )
    return CreatedRecords(
        ledger = ledger,
        category = category,
        transaction = transaction,
        otherExpense = otherExpense,
        budget = budget,
        recurringRule = recurringRule,
    )
}

// Records the expense of 1,700円 split into お弁当 1,200円 (食費) and 洗剤 500円 (日用品).
private suspend fun recordSplitExpense(
    scope: LedgerScope,
    categories: List<Category>,
): Transaction =
    scope.recordTransaction(
        transaction =
            NewTransaction(
                date = FIXTURE_DATE,
                direction = Direction.EXPENSE,
                amount = SPLIT_AMOUNT,
                categoryId = null,
                memo = MEMO_BEFORE,
                items =
                    listOf(
                        NewLineItem(
                            amount = FIRST_ITEM_AMOUNT,
                            categoryId = categories.idOf(name = "食費"),
                            name = FIRST_ITEM_NAME,
                        ),
                        NewLineItem(
                            amount = SECOND_ITEM_AMOUNT,
                            categoryId = categories.idOf(name = "日用品"),
                            name = SECOND_ITEM_NAME,
                        ),
                    ),
            ),
    )

// Every record has its own non-nil UUID and was created and updated at 12:00; the transaction names device D.
internal fun assertCreatedAtNoonOnDeviceD(created: CreatedRecords) {
    val records: List<SyncRecord> =
        listOf(created.ledger, created.category, created.transaction, created.budget, created.recurringRule) +
            created.transaction.items
    assertEquals(expected = 2, actual = created.transaction.items.size, message = "明細が 2 件でない")
    assertEquals(
        expected = records.size,
        actual =
            records
                .map { record -> record.id }
                .filter { id -> id != Uuid.NIL }
                .toSet()
                .size,
        message = "識別子が UUID として一意でない",
    )
    assertEquals(
        expected = List(size = records.size) { FIXTURE_NOON },
        actual = records.map { record -> record.createdAt },
        message = "作成時刻が 12:00 でない",
    )
    assertEquals(
        expected = List(size = records.size) { FIXTURE_NOON },
        actual = records.map { record -> record.updatedAt },
        message = "更新時刻が 12:00 でない",
    )
    assertEquals(expected = FIXTURE_DEVICE_ID, actual = created.transaction.deviceId)
    assertEquals(expected = SPLIT_AMOUNT, actual = created.transaction.amount)
}

// The deleted transaction is not found, not listed and not counted; the other expense still is.
internal suspend fun assertDeletedIsHidden(
    scope: LedgerScope,
    created: CreatedRecords,
) {
    assertNull(actual = scope.findTransaction(id = created.transaction.id), message = "削除した取引が見つかる")
    assertEquals(
        expected = listOf(created.otherExpense.id),
        actual = scope.transactions(month = FIXTURE_MONTH).map { listed -> listed.id },
        message = "削除した取引が一覧に残る",
    )
    assertEquals(
        expected = MonthTotals(expense = OTHER_EXPENSE_AMOUNT, income = 0L),
        actual = scope.monthTotals(month = FIXTURE_MONTH),
        message = "削除した取引が合計に数えられている",
    )
}

// The database still holds the transaction, with its two items, as a tombstone deleted at 12:05;
// every other record is held live.
internal suspend fun assertTombstoneIsHeld(
    store: LocalStore,
    created: CreatedRecords,
) {
    val snapshot = store.recordsIncludingTombstones()
    val tombstone = snapshot.transactions.single { stored -> stored.record.id == created.transaction.id }
    assertEquals(expected = FIXTURE_NOON_PLUS_FIVE, actual = tombstone.deletedAt, message = "削除時刻が 12:05 でない")
    assertEquals(expected = FIXTURE_NOON, actual = tombstone.record.createdAt)
    assertEquals(expected = MEMO_AFTER, actual = tombstone.record.memo)
    assertEquals(expected = FIXTURE_DEVICE_ID, actual = tombstone.record.deviceId)
    assertEquals(expected = SPLIT_AMOUNT, actual = tombstone.record.amount)
    assertEquals(
        expected = created.transaction.items.map { item -> item.id },
        actual = tombstone.record.items.map { item -> item.id },
        message = "墓標に明細が残っていない",
    )
    assertEquals(
        expected = listOf(FIRST_ITEM_NAME to FIRST_ITEM_AMOUNT, SECOND_ITEM_NAME to SECOND_ITEM_AMOUNT),
        actual = tombstone.record.items.map { item -> item.name to item.amount },
    )

    assertEquals(
        expected = listOf(created.transaction.id),
        actual = snapshot.transactions.filter { stored -> stored.deletedAt != null }.map { stored -> stored.record.id },
        message = "墓標が削除した取引だけでない",
    )
    val liveIds =
        (snapshot.ledgers + snapshot.categories + snapshot.transactions + snapshot.budgets + snapshot.recurringRules)
            .filter { stored -> stored.deletedAt == null }
            .map { stored -> stored.record.id }
            .toSet()
    val expectedLive =
        listOf(
            created.ledger.id,
            created.category.id,
            created.otherExpense.id,
            created.budget.id,
            created.recurringRule.id,
        )
    assertEquals(
        expected = expectedLive,
        actual = expectedLive.filter { id -> id in liveIds },
        message = "削除していない記録がデータベースに生きたまま残っていない",
    )
}

// The identifier of the category named `name` among these.
private fun List<Category>.idOf(name: String): Uuid = single { category -> category.name == name }.id

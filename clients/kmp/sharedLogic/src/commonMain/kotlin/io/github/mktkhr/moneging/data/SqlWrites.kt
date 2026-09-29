package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.Budget
import io.github.mktkhr.moneging.domain.NewRecurringRule
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.coroutines.withContext
import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

private const val MIN_AMOUNT = 1L
private const val FIRST_DAY_OF_MONTH = 1
private const val LAST_DAY_OF_MONTH = 31

/** [LedgerTransactionWrites] over the database, stamping [deviceId] on every transaction. */
internal class SqlTransactionWrites(
    private val rows: LedgerRows,
    private val deviceId: String,
) : LedgerTransactionWrites {
    private val queries = rows.database.transactionsQueries

    override suspend fun recordTransaction(transaction: NewTransaction): Transaction {
        requireShape(transaction)
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                transaction.categoryId?.let { rows.requireActiveCategory(it) }
                transaction.items.forEach { rows.requireActiveCategory(it.categoryId) }
                transaction.photoId?.let { rows.requirePhoto(it) }
                insert(transaction)
            }
        }
    }

    override suspend fun updateMemo(
        transactionId: Uuid,
        memo: String?,
    ): Transaction =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                requireNotNull(rows.transaction(transactionId)) { "記録が見つかりません" }
                queries.updateMemo(
                    memo = memo,
                    updated_at = rows.now().toColumn(),
                    ledger_id = rows.ledgerKey,
                    id = transactionId.toString(),
                )
                checkNotNull(rows.transaction(transactionId))
            }
        }

    override suspend fun deleteTransaction(transactionId: Uuid) {
        withContext(rows.context) {
            rows.database.transaction {
                requireNotNull(rows.transaction(transactionId)) { "記録が見つかりません" }
                queries.markTransactionDeleted(
                    deleted_at = rows.now().toColumn(),
                    ledger_id = rows.ledgerKey,
                    id = transactionId.toString(),
                )
            }
        }
    }

    private fun requireShape(transaction: NewTransaction) {
        require(transaction.amount >= MIN_AMOUNT) { "金額は1円以上にしてください" }
        if (transaction.items.isEmpty()) {
            requireNotNull(transaction.categoryId) { "カテゴリを選んでください" }
        } else {
            require(transaction.categoryId == null) { "明細のある記録にはカテゴリを付けません" }
            require(transaction.items.all { it.amount >= MIN_AMOUNT }) { "明細の金額は1円以上にしてください" }
            require(transaction.items.sumOf { it.amount } == transaction.amount) { "明細の合計が金額と一致しません" }
        }
    }

    private fun insert(transaction: NewTransaction): Transaction {
        val now = rows.now().toColumn()
        val id = Uuid.random()
        queries.insertTransaction(
            id = id.toString(),
            ledger_id = rows.ledgerKey,
            date = transaction.date.toString(),
            direction = transaction.direction.name,
            amount = transaction.amount,
            category_id = transaction.categoryId?.toString(),
            memo = transaction.memo,
            store_name = transaction.storeName,
            photo_id = transaction.photoId?.toString(),
            needs_review = false.toColumn(),
            device_id = deviceId,
            created_at = now,
            updated_at = now,
        )
        transaction.items.forEachIndexed { position, item ->
            queries.insertLineItem(
                id = Uuid.random().toString(),
                transaction_id = id.toString(),
                position = position.toLong(),
                amount = item.amount,
                category_id = item.categoryId.toString(),
                name = item.name,
                created_at = now,
                updated_at = now,
            )
        }
        return checkNotNull(rows.transaction(id))
    }
}

/** [LedgerPlans] over the database. */
internal class SqlPlans(
    private val rows: LedgerRows,
) : LedgerPlans {
    override suspend fun setBudget(
        categoryId: Uuid?,
        amount: Long,
        from: YearMonth,
    ): Budget {
        require(amount >= 0L) { "予算は0円以上にしてください" }
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                categoryId?.let { rows.requireActiveCategory(it) }
                val now = rows.now()
                val budget =
                    Budget(
                        id = Uuid.random(),
                        ledgerId = rows.ledgerId,
                        categoryId = categoryId,
                        amount = amount,
                        fromMonth = from,
                        createdAt = now,
                        updatedAt = now,
                    )
                rows.database.budgetsQueries.insertBudget(
                    id = budget.id.toString(),
                    ledger_id = rows.ledgerKey,
                    category_id = categoryId?.toString(),
                    amount = amount,
                    from_month = from.toString(),
                    created_at = now.toColumn(),
                    updated_at = now.toColumn(),
                )
                budget
            }
        }
    }

    override suspend fun createRecurringRule(rule: NewRecurringRule): RecurringRule {
        require(rule.amount >= MIN_AMOUNT) { "金額は1円以上にしてください" }
        require(rule.dayOfMonth in FIRST_DAY_OF_MONTH..LAST_DAY_OF_MONTH) { "日付は1〜31日にしてください" }
        require(rule.endMonth == null || rule.endMonth >= rule.startMonth) { "終了月は開始月以降にしてください" }
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                rows.requireActiveCategory(rule.categoryId)
                val now = rows.now()
                val created =
                    RecurringRule(
                        id = Uuid.random(),
                        ledgerId = rows.ledgerId,
                        direction = rule.direction,
                        amount = rule.amount,
                        categoryId = rule.categoryId,
                        dayOfMonth = rule.dayOfMonth,
                        startMonth = rule.startMonth,
                        endMonth = rule.endMonth,
                        memo = rule.memo,
                        createdAt = now,
                        updatedAt = now,
                    )
                rows.database.recurringRulesQueries.insertRecurringRule(
                    id = created.id.toString(),
                    ledger_id = rows.ledgerKey,
                    direction = rule.direction.name,
                    amount = rule.amount,
                    category_id = rule.categoryId.toString(),
                    day_of_month = rule.dayOfMonth.toLong(),
                    start_month = rule.startMonth.toString(),
                    end_month = rule.endMonth?.toString(),
                    memo = rule.memo,
                    created_at = now.toColumn(),
                    updated_at = now.toColumn(),
                )
                created
            }
        }
    }
}

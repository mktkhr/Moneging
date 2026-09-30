package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.coroutines.withContext
import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

/** The least amount of a transaction, an item or a rule, in yen. */
internal const val MIN_AMOUNT = 1L

private const val NOT_FOUND = "記録が見つかりません"

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
                transaction.categoryIds().forEach { rows.requireActiveCategory(it) }
                transaction.photoId?.let { rows.requirePhoto(it) }
                insertTransaction(rows = rows, deviceId = deviceId, transaction = transaction)
            }
        }
    }

    override suspend fun updateTransaction(
        transactionId: Uuid,
        transaction: NewTransaction,
    ): Transaction {
        requireShape(transaction)
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                val current = requireNotNull(rows.transaction(transactionId)) { NOT_FOUND }
                // A category archived since may stay on the transaction; only a newly chosen one must be active.
                val kept = current.categoryIds()
                transaction.categoryIds().forEach { id ->
                    if (id in kept) rows.requireCategory(id) else rows.requireActiveCategory(id)
                }
                transaction.photoId?.let { rows.requirePhoto(it) }
                val now = rows.now().toColumn()
                queries.updateTransaction(
                    date = transaction.date.toString(),
                    direction = transaction.direction.name,
                    amount = transaction.amount,
                    categoryId = transaction.categoryId?.toString(),
                    memo = transaction.memo,
                    storeName = transaction.storeName,
                    photoId = transaction.photoId?.toString(),
                    updatedAt = now,
                    ledgerId = rows.ledgerKey,
                    id = transactionId.toString(),
                )
                queries.deleteLineItemsOf(transactionId.toString())
                insertLineItems(rows = rows, transactionId = transactionId, transaction = transaction, now = now)
                checkNotNull(rows.transaction(transactionId))
            }
        }
    }

    override suspend fun updateMemo(
        transactionId: Uuid,
        memo: String?,
    ): Transaction =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                requireNotNull(rows.transaction(transactionId)) { NOT_FOUND }
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
                requireNotNull(rows.transaction(transactionId)) { NOT_FOUND }
                queries.markTransactionDeleted(
                    deleted_at = rows.now().toColumn(),
                    ledger_id = rows.ledgerKey,
                    id = transactionId.toString(),
                )
            }
        }
    }

    // The invariants of PRODUCT.md §3 that need no database: the amount, and
    // an expense's category or items, an income's lack of both.
    private fun requireShape(transaction: NewTransaction) {
        require(transaction.amount >= MIN_AMOUNT) { "金額は1円以上にしてください" }
        when (transaction.direction) {
            Direction.INCOME -> {
                require(transaction.categoryId == null) { "収入には分類を付けません" }
                require(transaction.items.isEmpty()) { "収入は明細に分けられません" }
            }

            Direction.EXPENSE -> {
                if (transaction.items.isEmpty()) {
                    requireNotNull(transaction.categoryId) { "カテゴリを選んでください" }
                } else {
                    require(transaction.categoryId == null) { "明細のある記録にはカテゴリを付けません" }
                    require(transaction.items.all { it.amount >= MIN_AMOUNT }) { "明細の金額は1円以上にしてください" }
                    require(transaction.items.sumOf { it.amount } == transaction.amount) {
                        "明細の合計が金額と一致しません"
                    }
                }
            }
        }
    }
}

// Every category a transaction names: its own and its items'.
internal fun NewTransaction.categoryIds(): Set<Uuid> = (listOfNotNull(categoryId) + items.map { it.categoryId }).toSet()

internal fun Transaction.categoryIds(): Set<Uuid> = (listOfNotNull(categoryId) + items.map { it.categoryId }).toSet()

/**
 * Inserts [transaction] into [rows]' ledger, stamped with [deviceId], as the
 * month [recurringMonth] of the rule [recurringRuleId] when it is one's.
 * Validates nothing: the caller has, within the same database transaction.
 */
internal fun insertTransaction(
    rows: LedgerRows,
    deviceId: String,
    transaction: NewTransaction,
    recurringRuleId: Uuid? = null,
    recurringMonth: YearMonth? = null,
): Transaction {
    val now = rows.now().toColumn()
    val id = Uuid.random()
    rows.database.transactionsQueries.insertTransaction(
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
        recurring_rule_id = recurringRuleId?.toString(),
        recurring_month = recurringMonth?.toString(),
    )
    insertLineItems(rows = rows, transactionId = id, transaction = transaction, now = now)
    return checkNotNull(rows.transaction(id))
}

internal fun insertLineItems(
    rows: LedgerRows,
    transactionId: Uuid,
    transaction: NewTransaction,
    now: Long,
) {
    transaction.items.forEachIndexed { position, item ->
        rows.database.transactionsQueries.insertLineItem(
            id = Uuid.random().toString(),
            transaction_id = transactionId.toString(),
            position = position.toLong(),
            amount = item.amount,
            category_id = item.categoryId.toString(),
            name = item.name,
            created_at = now,
            updated_at = now,
        )
    }
}

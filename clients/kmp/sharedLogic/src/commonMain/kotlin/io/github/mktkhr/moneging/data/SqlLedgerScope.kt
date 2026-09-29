package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.MonthTotals
import io.github.mktkhr.moneging.domain.Photo
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.domain.TransactionQuery
import kotlinx.coroutines.withContext
import kotlinx.datetime.YearMonth
import kotlin.time.Instant
import kotlin.uuid.Uuid

/**
 * [LedgerScope] over the database, one part per concern, all reading and
 * writing through [LedgerRows], whose every query names the ledger. A write
 * validates everything it refers to inside its database transaction, so a
 * refused write leaves nothing behind.
 */
internal class SqlLedgerScope(
    rows: LedgerRows,
    photoFiles: PhotoFiles,
    deviceId: String,
) : LedgerScope,
    LedgerCategories by SqlCategories(rows),
    LedgerPhotos by SqlPhotos(rows, photoFiles),
    LedgerTransactionReads by SqlTransactionReads(rows),
    LedgerReports by SqlReports(rows),
    LedgerTransactionWrites by SqlTransactionWrites(rows, deviceId),
    LedgerPlans by SqlPlans(rows),
    LedgerRecurringRules by SqlRecurringRules(rows, deviceId) {
    override val ledgerId: Uuid = rows.ledgerId
}

/** [LedgerCategories] over the database. */
internal class SqlCategories(
    private val rows: LedgerRows,
) : LedgerCategories {
    private val queries = rows.database.categoriesQueries

    override suspend fun categories(): List<Category> =
        withContext(rows.context) {
            queries
                .liveCategories(rows.ledgerKey)
                .executeAsList()
                .map { it.toDomain() }
        }

    override suspend fun findCategory(id: Uuid): Category? = withContext(rows.context) { rows.category(id) }

    override suspend fun createCategory(name: String): Category {
        val trimmed = requireCategoryName(name)
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                val now = rows.now().toColumn()
                val id = Uuid.random()
                queries.insertCategory(
                    id = id.toString(),
                    ledger_id = rows.ledgerKey,
                    name = trimmed,
                    position = queries.nextCategoryPosition(rows.ledgerKey).executeAsOne(),
                    created_at = now,
                    updated_at = now,
                )
                rows.requireCategory(id)
            }
        }
    }

    override suspend fun renameCategory(
        categoryId: Uuid,
        name: String,
    ): Category {
        val trimmed = requireCategoryName(name)
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireCategory(categoryId)
                queries.renameCategory(
                    name = trimmed,
                    updated_at = rows.now().toColumn(),
                    ledger_id = rows.ledgerKey,
                    id = categoryId.toString(),
                )
                rows.requireCategory(categoryId)
            }
        }
    }

    override suspend fun archiveCategory(categoryId: Uuid): Category =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireCategory(categoryId)
                queries.archiveCategory(
                    updated_at = rows.now().toColumn(),
                    ledger_id = rows.ledgerKey,
                    id = categoryId.toString(),
                )
                rows.requireCategory(categoryId)
            }
        }

    private fun requireCategoryName(name: String): String {
        val trimmed = name.trim()
        require(trimmed.isNotEmpty()) { "カテゴリの名前を入力してください" }
        return trimmed
    }
}

/** [LedgerPhotos] over the database, the bytes in [photoFiles]. */
internal class SqlPhotos(
    private val rows: LedgerRows,
    private val photoFiles: PhotoFiles,
) : LedgerPhotos {
    override suspend fun addPhoto(
        bytes: ByteArray,
        contentType: String,
        capturedAt: Instant,
    ): Photo =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                val now = rows.now()
                val photo =
                    Photo(
                        id = Uuid.random(),
                        ledgerId = rows.ledgerId,
                        contentType = contentType,
                        sizeBytes = bytes.size.toLong(),
                        capturedAt = capturedAt,
                        createdAt = now,
                        updatedAt = now,
                    )
                rows.database.photosQueries.insertPhoto(
                    id = photo.id.toString(),
                    ledger_id = rows.ledgerKey,
                    content_type = contentType,
                    size_bytes = photo.sizeBytes,
                    captured_at = capturedAt.toColumn(),
                    created_at = now.toColumn(),
                    updated_at = now.toColumn(),
                )
                photoFiles.write(id = photo.id, bytes = bytes)
                photo
            }
        }

    override suspend fun findPhoto(id: Uuid): Photo? =
        withContext(rows.context) {
            rows.database.photosQueries
                .livePhoto(ledger_id = rows.ledgerKey, id = id.toString())
                .executeAsOneOrNull()
                ?.toDomain()
        }
}

/** [LedgerTransactionReads] over the database. */
internal class SqlTransactionReads(
    private val rows: LedgerRows,
) : LedgerTransactionReads {
    private val queries = rows.database.transactionsQueries

    override suspend fun findTransaction(id: Uuid): Transaction? = withContext(rows.context) { rows.transaction(id) }

    override suspend fun transactions(month: YearMonth): List<Transaction> =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                val listed =
                    queries.liveTransactionsBetween(
                        ledgerId = rows.ledgerKey,
                        fromDate = month.firstDay.toString(),
                        toDate = month.lastDay.toString(),
                    )
                listed.executeAsList().map { row -> row.toDomain(items = itemsOf(rows.database, row.id)) }
            }
        }

    override suspend fun monthTotals(month: YearMonth): MonthTotals =
        withContext(rows.context) {
            val totals =
                queries.totalsBetween(
                    ledgerId = rows.ledgerKey,
                    fromDate = month.firstDay.toString(),
                    toDate = month.lastDay.toString(),
                )
            val byDirection = totals.executeAsList().associate { row -> Direction.valueOf(row.direction) to row.total }
            MonthTotals(
                expense = byDirection[Direction.EXPENSE] ?: 0L,
                income = byDirection[Direction.INCOME] ?: 0L,
            )
        }

    override suspend fun searchTransactions(query: TransactionQuery): List<Transaction> =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                val found =
                    queries.searchTransactions(
                        ledgerId = rows.ledgerKey,
                        fromDate = query.from?.toString(),
                        toDate = query.to?.toString(),
                        minAmount = query.minAmount,
                        maxAmount = query.maxAmount,
                        categoryId = query.categoryId?.toString(),
                        text = query.text?.takeIf { it.isNotEmpty() },
                    )
                found.executeAsList().map { row -> row.toDomain(items = itemsOf(rows.database, row.id)) }
            }
        }
}

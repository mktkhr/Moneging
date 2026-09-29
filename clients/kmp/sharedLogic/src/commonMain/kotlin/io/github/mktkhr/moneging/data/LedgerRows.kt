package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.data.db.MonegingDatabase
import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.LineItem
import io.github.mktkhr.moneging.domain.StoredRecord
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlin.coroutines.CoroutineContext
import kotlin.time.Clock
import kotlin.time.Instant
import kotlin.uuid.Uuid

/**
 * One ledger's live rows, read by identifier: every query names the ledger,
 * so a record of another ledger is never found. Shared by the parts of
 * [SqlLedgerScope], with what they need to write (the clock, the context
 * the database is used on).
 */
internal class LedgerRows(
    /** The ledger. */
    val ledgerId: Uuid,
    /** The database. */
    val database: MonegingDatabase,
    /** The instant a write is stamped with. */
    val now: () -> Instant,
    /** Where the database is used. */
    val context: CoroutineContext,
) {
    /** [ledgerId] as the database keeps it. */
    val ledgerKey: String = ledgerId.toString()

    /** Today's date by the clock, in Asia/Tokyo. */
    fun today(): LocalDate = now().toLocalDateTime(PRODUCT_TIME_ZONE).date

    /** Refuses a write to a ledger that does not exist. */
    fun requireLedger() {
        requireNotNull(database.ledgersQueries.liveLedger(ledgerKey).executeAsOneOrNull()) { "家計簿が見つかりません" }
    }

    /** This ledger's live category [id], or `null`. */
    fun category(id: Uuid): Category? =
        database.categoriesQueries
            .liveCategory(ledger_id = ledgerKey, id = id.toString())
            .executeAsOneOrNull()
            ?.toDomain()

    /** This ledger's live category [id]; refuses another ledger's or an unknown one. */
    fun requireCategory(id: Uuid): Category = requireNotNull(category(id)) { "この家計簿のカテゴリではありません" }

    /**
     * Refuses a category that is not one of this ledger's, or that is
     * archived: another ledger's is refused exactly like one that does not
     * exist.
     */
    fun requireActiveCategory(id: Uuid) {
        val category = requireCategory(id)
        require(!category.isArchived) { "アーカイブ済みのカテゴリには記録できません" }
    }

    /** Refuses a photo that is not one of this ledger's. */
    fun requirePhoto(id: Uuid) {
        requireNotNull(
            database.photosQueries.livePhoto(ledger_id = ledgerKey, id = id.toString()).executeAsOneOrNull(),
        ) { "この家計簿の写真ではありません" }
    }

    /** This ledger's live transaction [id] with its items, or `null`. */
    fun transaction(id: Uuid): Transaction? =
        database.transactionsQueries
            .liveTransaction(ledger_id = ledgerKey, id = id.toString())
            .executeAsOneOrNull()
            ?.let { row -> row.toDomain(items = itemsOf(database, row.id)) }
}

/** The time zone the product reads dates in (PRODUCT.md §3: Asia/Tokyo). */
internal val PRODUCT_TIME_ZONE: TimeZone = TimeZone.of("Asia/Tokyo")

/** Today's date by this clock, in Asia/Tokyo. */
internal fun Clock.todayInTokyo(): LocalDate = now().toLocalDateTime(PRODUCT_TIME_ZONE).date

/** The line items of the transaction [transactionId], in order. */
internal fun itemsOf(
    database: MonegingDatabase,
    transactionId: String,
): List<LineItem> =
    database.transactionsQueries
        .lineItemsOf(transactionId)
        .executeAsList()
        .map { it.toDomain() }

/** Every transaction of every ledger, tombstones included, each with its items. */
internal fun allTransactions(database: MonegingDatabase): List<StoredRecord<Transaction>> =
    database.transactionsQueries.allTransactions().executeAsList().map { row ->
        StoredRecord(record = row.toDomain(items = itemsOf(database, row.id)), deletedAt = row.deleted_at?.toInstant())
    }

package io.github.mktkhr.moneging.data

import app.cash.sqldelight.coroutines.asFlow
import app.cash.sqldelight.coroutines.mapToList
import app.cash.sqldelight.db.SqlDriver
import io.github.mktkhr.moneging.data.db.MonegingDatabase
import io.github.mktkhr.moneging.domain.Ledger
import io.github.mktkhr.moneging.domain.LedgerName
import io.github.mktkhr.moneging.domain.RecordSnapshot
import io.github.mktkhr.moneging.domain.StoredRecord
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.withContext
import kotlin.coroutines.CoroutineContext
import kotlin.time.Clock
import kotlin.time.Instant
import kotlin.uuid.Uuid

/**
 * The on-device database (PRODUCT.md §6): every ledger and every record in
 * it, reached only through this class.
 *
 * Records are sync-ready: each gets a UUID generated here and the instants
 * it was created and last updated, read from the injected [Clock]; a
 * deletion leaves a tombstone. Everything within a ledger goes through
 * [ledger], which never reads or writes another ledger's records.
 */
class LocalStore internal constructor(
    openDriver: () -> SqlDriver,
    private val clock: Clock,
    private val deviceId: String,
    private val photoFiles: PhotoFiles,
    private val context: CoroutineContext = Dispatchers.Default,
) {
    private val database = MonegingDatabase(openDriver())

    /** Creates the ledger named [name] (trimmed), with the default categories; refuses a name the rule refuses. */
    suspend fun createLedger(name: String): Ledger {
        val normalized = requireLedgerName(name)
        return withContext(context) {
            val now = now()
            val ledger = Ledger(id = Uuid.random(), name = normalized, createdAt = now, updatedAt = now)
            database.transaction {
                database.ledgersQueries.insertLedger(
                    id = ledger.id.toString(),
                    name = ledger.name,
                    created_at = now.toColumn(),
                    updated_at = now.toColumn(),
                )
                DEFAULT_CATEGORY_NAMES.forEachIndexed { position, categoryName ->
                    database.categoriesQueries.insertCategory(
                        id = Uuid.random().toString(),
                        ledger_id = ledger.id.toString(),
                        name = categoryName,
                        position = position.toLong(),
                        created_at = now.toColumn(),
                        updated_at = now.toColumn(),
                    )
                }
            }
            ledger
        }
    }

    /** The ledgers on the device, in creation order. */
    suspend fun ledgers(): List<Ledger> =
        withContext(context) {
            database.ledgersQueries
                .liveLedgers()
                .executeAsList()
                .map { it.toDomain() }
        }

    /** The ledgers on the device, in creation order, again whenever they change. */
    fun observeLedgers(): Flow<List<Ledger>> =
        database.ledgersQueries
            .liveLedgers()
            .asFlow()
            .mapToList(context)
            .map { rows -> rows.map { it.toDomain() } }

    /**
     * Emits at once, then whenever a transaction, a category or a recurring
     * rule of any ledger changes: when to read a ledger's records again.
     */
    fun observeRecordChanges(): Flow<Unit> =
        merge(
            database.transactionsQueries.allTransactions().asFlow(),
            database.categoriesQueries.allCategories().asFlow(),
            database.recurringRulesQueries.allRecurringRules().asFlow(),
        ).map { }

    /** The ledger [id], or `null` when there is none. */
    suspend fun findLedger(id: Uuid): Ledger? =
        withContext(context) {
            database.ledgersQueries
                .liveLedger(id.toString())
                .executeAsOneOrNull()
                ?.toDomain()
        }

    /** Renames the ledger [id] to [name] (trimmed); refuses a name the rule refuses and an unknown ledger. */
    suspend fun renameLedger(
        id: Uuid,
        name: String,
    ): Ledger {
        val normalized = requireLedgerName(name)
        return withContext(context) {
            database.transactionWithResult {
                val current = database.ledgersQueries.liveLedger(id.toString()).executeAsOneOrNull()
                requireNotNull(current) { "家計簿が見つかりません" }
                val now = now()
                database.ledgersQueries.renameLedger(name = normalized, updated_at = now.toColumn(), id = id.toString())
                current.toDomain().copy(name = normalized, updatedAt = now)
            }
        }
    }

    /** The operations within the ledger [id]; none of them reaches another ledger. */
    fun ledger(id: Uuid): LedgerScope =
        SqlLedgerScope(
            rows = LedgerRows(ledgerId = id, database = database, now = ::now, context = context),
            photoFiles = photoFiles,
            deviceId = deviceId,
        )

    /** The whole database, tombstones included (sync and backup). */
    suspend fun recordsIncludingTombstones(): RecordSnapshot =
        withContext(context) {
            database.transactionWithResult {
                RecordSnapshot(
                    ledgers =
                        database.ledgersQueries
                            .allLedgers()
                            .executeAsList()
                            .map { StoredRecord(record = it.toDomain(), deletedAt = it.deleted_at?.toInstant()) },
                    categories =
                        database.categoriesQueries
                            .allCategories()
                            .executeAsList()
                            .map { StoredRecord(record = it.toDomain(), deletedAt = it.deleted_at?.toInstant()) },
                    transactions = allTransactions(database),
                    photos =
                        database.photosQueries
                            .allPhotos()
                            .executeAsList()
                            .map { StoredRecord(record = it.toDomain(), deletedAt = it.deleted_at?.toInstant()) },
                    budgets =
                        database.budgetsQueries
                            .allBudgets()
                            .executeAsList()
                            .map { StoredRecord(record = it.toDomain(), deletedAt = it.deleted_at?.toInstant()) },
                    recurringRules =
                        database.recurringRulesQueries
                            .allRecurringRules()
                            .executeAsList()
                            .map { StoredRecord(record = it.toDomain(), deletedAt = it.deleted_at?.toInstant()) },
                )
            }
        }

    // Millisecond precision: what the database keeps, so a record read back
    // equals the one returned when it was written.
    private fun now(): Instant = clock.now().toColumn().toInstant()

    private fun requireLedgerName(name: String): String =
        requireNotNull(LedgerName.normalized(name)) {
            "家計簿の名前は前後の空白を除いて1〜${LedgerName.MAX_LENGTH}文字にしてください"
        }

    /** Factories for the store. */
    companion object {
        /**
         * An empty store held in memory, for tests: nothing is written to
         * disk and nothing outlives the store.
         */
        fun inMemory(
            clock: Clock,
            deviceId: String,
        ): LocalStore =
            LocalStore(
                openDriver = ::inMemoryDriver,
                clock = clock,
                deviceId = deviceId,
                photoFiles = InMemoryPhotoFiles(),
            )
    }
}

/** A fresh, private in-memory database with the current schema. */
internal expect fun inMemoryDriver(): SqlDriver

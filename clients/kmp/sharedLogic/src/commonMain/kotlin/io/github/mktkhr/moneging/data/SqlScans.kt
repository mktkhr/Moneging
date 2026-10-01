package io.github.mktkhr.moneging.data

import app.cash.sqldelight.coroutines.asFlow
import app.cash.sqldelight.coroutines.mapToOneOrNull
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.DraftCorrection
import io.github.mktkhr.moneging.scan.DraftItem
import io.github.mktkhr.moneging.scan.ReadingMethod
import io.github.mktkhr.moneging.scan.ScanJob
import io.github.mktkhr.moneging.scan.ScanState
import io.github.mktkhr.moneging.scan.ScannedValue
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.transformWhile
import kotlinx.coroutines.withContext
import kotlin.uuid.Uuid

/** The confidence of a value the user corrected: they read it themselves. */
internal const val CORRECTED_CONFIDENCE = 1.0

/** The name of the item a mismatch accepted below the total adds (PRODUCT.md §3, Draft). */
internal const val DIFFERENCE_ITEM_NAME = "差額"

private const val DRAFT_NOT_FOUND = "下書きが見つかりません"
private const val OTHER_CATEGORY_NAME = "その他"
private const val TOTAL_TOO_SMALL = "合計は1円以上にしてください"

/** [LedgerScans] over the database; the jobs run on [runner]. */
internal class SqlScans(
    private val rows: LedgerRows,
    private val runner: ScanRunner,
    private val deviceId: String,
) : LedgerScans {
    private val queries = rows.database.scansQueries

    override suspend fun startScan(
        photoId: Uuid,
        method: ReadingMethod?,
    ): ScanJob {
        val readBy = method ?: runner.chosenMethod
        val job =
            withContext(rows.context) {
                rows.database.transactionWithResult {
                    rows.requireLedger()
                    rows.requirePhoto(photoId)
                    val now = rows.now().toColumn()
                    val id = Uuid.random()
                    queries.insertScanJob(
                        id = id.toString(),
                        ledger_id = rows.ledgerKey,
                        photo_id = photoId.toString(),
                        created_at = now,
                        updated_at = now,
                        method = readBy.name,
                    )
                    checkNotNull(rows.scanJob(id))
                }
            }
        runner.run(ledgerId = rows.ledgerId, jobId = job.id, photoId = photoId, method = readBy)
        return job
    }

    override suspend fun findScanJob(id: Uuid): ScanJob? = withContext(rows.context) { rows.scanJob(id) }

    override fun observeScanJob(jobId: Uuid): Flow<ScanJob> =
        queries
            .liveScanJob(ledger_id = rows.ledgerKey, id = jobId.toString())
            .asFlow()
            .mapToOneOrNull(rows.context)
            .distinctUntilChanged()
            .transformWhile { row ->
                if (row != null) emit(row.toDomain())
                row != null
            }

    override suspend fun scanJobs(state: ScanState?): List<ScanJob> =
        withContext(rows.context) {
            queries
                .liveScanJobs(rows.ledgerKey)
                .executeAsList()
                .map { it.toDomain() }
                .filter { state == null || it.state == state }
        }

    override suspend fun waitingDrafts(): List<Draft> =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                queries.liveDrafts(rows.ledgerKey).executeAsList().map { it.toDomain(items = rows.draftItems(it.id)) }
            }
        }

    override suspend fun findDraft(id: Uuid): Draft? = withContext(rows.context) { rows.draft(id) }

    override suspend fun updateDraft(
        draftId: Uuid,
        correction: DraftCorrection,
    ): Draft {
        correction.total?.let { require(it >= MIN_AMOUNT) { TOTAL_TOO_SMALL } }
        val items = correction.items.orEmpty()
        requireItemAmounts(items.map { it.amount })
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                val current = requireNotNull(rows.draft(draftId)) { DRAFT_NOT_FOUND }
                (
                    listOfNotNull(
                        correction.category?.id,
                    ) + items.mapNotNull { it.categoryId }
                ).forEach { rows.requireCategory(it) }
                rows.writeDraft(current = current, corrected = current.corrected(correction))
                checkNotNull(rows.draft(draftId))
            }
        }
    }

    override suspend fun confirmDraft(
        draftId: Uuid,
        acceptMismatch: Boolean,
    ): Transaction =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                val draft = requireNotNull(rows.draft(draftId)) { DRAFT_NOT_FOUND }
                require(draft.total.value >= MIN_AMOUNT) { TOTAL_TOO_SMALL }
                val confirmed = draft.toNewTransaction(other = rows.otherCategoryId(), acceptMismatch = acceptMismatch)
                confirmed.categoryIds().forEach { rows.requireCategory(it) }
                val transaction = insertTransaction(rows = rows, deviceId = deviceId, transaction = confirmed)
                val sum = draft.itemsSum
                if (sum != null && sum != draft.total.value) {
                    rows.database.transactionsQueries.markNeedsReview(
                        ledger_id = rows.ledgerKey,
                        id = transaction.id.toString(),
                    )
                }
                queries.markDraftDeleted(
                    deletedAt = rows.now().toColumn(),
                    ledgerId = rows.ledgerKey,
                    id = draftId.toString(),
                )
                transaction
            }
        }

    override suspend fun discardDraft(draftId: Uuid) {
        withContext(rows.context) {
            rows.database.transaction {
                requireNotNull(rows.draft(draftId)) { DRAFT_NOT_FOUND }
                queries.markDraftDeleted(
                    deletedAt = rows.now().toColumn(),
                    ledgerId = rows.ledgerKey,
                    id = draftId.toString(),
                )
            }
        }
    }
}

/** [LedgerRecognizedTexts] over the database. */
internal class SqlRecognizedTexts(
    private val rows: LedgerRows,
) : LedgerRecognizedTexts {
    override suspend fun recognizedText(scanId: Uuid): String? =
        withContext(rows.context) {
            rows.database.scansQueries
                .recognizedTextOf(ledgerId = rows.ledgerKey, id = scanId.toString())
                .executeAsList()
                .firstNotNullOfOrNull { it.recognized_text }
        }
}

internal fun LedgerRows.scanJob(id: Uuid): ScanJob? =
    database.scansQueries
        .liveScanJob(ledger_id = ledgerKey, id = id.toString())
        .executeAsOneOrNull()
        ?.toDomain()

internal fun LedgerRows.draft(id: Uuid): Draft? =
    database.scansQueries
        .liveDraft(ledger_id = ledgerKey, id = id.toString())
        .executeAsOneOrNull()
        ?.let { it.toDomain(items = draftItems(it.id)) }

internal fun LedgerRows.draftItems(draftId: String): List<DraftItem> =
    database.scansQueries
        .draftItemsOf(draftId)
        .executeAsList()
        .map { it.toDomain() }

internal fun LedgerRows.writeDraft(
    current: Draft,
    corrected: Draft,
) {
    database.scansQueries.updateDraft(
        store = corrected.store.value,
        storeConfidence = corrected.store.confidence,
        date = corrected.date.value.toString(),
        dateConfidence = corrected.date.confidence,
        total = corrected.total.value,
        totalConfidence = corrected.total.confidence,
        categoryId = corrected.categoryId?.toString(),
        updatedAt = now().toColumn(),
        ledgerId = ledgerKey,
        id = current.id.toString(),
    )
    if (corrected.items != current.items) {
        database.scansQueries.deleteDraftItemsOf(current.id.toString())
        insertDraftItems(rows = this, draftId = current.id, items = corrected.items)
    }
}

// その他 of this ledger: where an item or an expense without a category is confirmed.
internal fun LedgerRows.otherCategoryId(): Uuid {
    val categories =
        database.categoriesQueries
            .liveCategories(ledgerKey)
            .executeAsList()
            .map { it.toDomain() }
    val other = DEFAULT_CATEGORY_NAMES.indexOf(OTHER_CATEGORY_NAME)
    return checkNotNull(categories.firstOrNull { it.defaultIndex == other }) { "その他の分類がありません" }.id
}

// This draft with [correction] applied: a corrected store, date or total becomes certain.
internal fun Draft.corrected(correction: DraftCorrection): Draft =
    copy(
        store = correction.store?.let { correctedValue(store, it) } ?: store,
        date = correction.date?.let { correctedValue(date, it) } ?: date,
        total = correction.total?.let { correctedValue(total, it) } ?: total,
        categoryId = correction.category?.id ?: categoryId.takeIf { correction.category == null },
        items = correction.items ?: items,
    )

internal fun <T> correctedValue(
    current: ScannedValue<T>,
    value: T,
): ScannedValue<T> =
    if (current.value ==
        value
    ) {
        current
    } else {
        ScannedValue(value = value, confidence = CORRECTED_CONFIDENCE)
    }

// The sum of the items, or `null` for a draft without items.
internal val Draft.itemsSum: Long?
    get() = items.takeIf { it.isNotEmpty() }?.sumOf { it.amount }

// The expense this draft confirms into (PRODUCT.md §3, Draft): its items
// split it, each without a category in [other]; without items it is the
// total in its category or [other]. Items that do not add up are refused
// unless [acceptMismatch]: below the total a `差額` item makes up the
// difference, above it the expense is the items' sum.
internal fun Draft.toNewTransaction(
    other: Uuid,
    acceptMismatch: Boolean,
): NewTransaction {
    val sum = itemsSum
    val base =
        NewTransaction(
            date = date.value,
            direction = Direction.EXPENSE,
            amount = total.value,
            categoryId = null,
            storeName = store.value.trim().ifEmpty { null },
            photoId = photoId,
        )
    if (sum == null) return base.copy(categoryId = categoryId ?: other)
    // A discount item without a category is in the other items' category when they all share one.
    val sharedCategory =
        items
            .asSequence()
            .filter { it.amount > 0L }
            .map { it.categoryId }
            .distinct()
            .singleOrNull()
    val lineItems =
        items.map { item ->
            val discountCategory = sharedCategory.takeIf { item.amount < 0L }
            NewLineItem(
                amount = item.amount,
                categoryId = item.categoryId ?: discountCategory ?: other,
                name = item.name.trim().ifEmpty { null },
            )
        }
    require(sum == total.value || acceptMismatch) { "明細の合計 ${sum}円 が合計 ${total.value}円 と合いません" }
    return when {
        sum == total.value -> {
            base.copy(items = lineItems)
        }

        sum < total.value -> {
            val sameCategory = lineItems.map { it.categoryId }.distinct().singleOrNull() ?: other
            val difference =
                NewLineItem(amount = total.value - sum, categoryId = sameCategory, name = DIFFERENCE_ITEM_NAME)
            base.copy(items = lineItems + difference)
        }

        else -> {
            base.copy(amount = sum, items = lineItems)
        }
    }
}

/** Inserts [items] as the items of the draft [draftId], in order. */
internal fun insertDraftItems(
    rows: LedgerRows,
    draftId: Uuid,
    items: List<DraftItem>,
) {
    items.forEachIndexed { position, item ->
        rows.database.scansQueries.insertDraftItem(
            id = Uuid.random().toString(),
            draft_id = draftId.toString(),
            position = position.toLong(),
            name = item.name,
            amount = item.amount,
            category_id = item.categoryId?.toString(),
            confidence = item.confidence,
        )
    }
}

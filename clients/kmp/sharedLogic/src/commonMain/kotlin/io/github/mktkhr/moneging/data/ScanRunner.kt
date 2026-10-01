package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.data.db.MonegingDatabase
import io.github.mktkhr.moneging.scan.DraftItem
import io.github.mktkhr.moneging.scan.ReadingMethod
import io.github.mktkhr.moneging.scan.ReceiptReading
import io.github.mktkhr.moneging.scan.ScanState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.datetime.toLocalDateTime
import kotlin.coroutines.CoroutineContext
import kotlin.time.Duration
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Instant
import kotlin.uuid.Uuid

/** How long a scan may read before its job fails (PRODUCT.md §3, Scan job: its deadline). */
internal val SCAN_DEADLINE: Duration = 2.minutes

private const val DEADLINE_PASSED = "時間内に読み取れませんでした"
private const val UNREADABLE = "読み取れませんでした"
private const val NOTHING_READ = "金額が読み取れませんでした"
private const val PHOTO_GONE = "写真が見つかりませんでした"

/** The reason a job cut off by the app ending carries. */
internal const val CUT_OFF = "アプリが終了したため読み取れませんでした"

/**
 * Runs scan jobs in the background, off the caller (PRODUCT.md §6,
 * Asynchrony): each reads its photo and moves its job
 * `queued → running → succeeded` (leaving a draft) or `→ failed` (with a
 * reason), with [scanning]'s scanner as its pacer lets it. A scan that
 * throws or passes [SCAN_DEADLINE] fails; one cut off by the app ending is
 * failed on the next start.
 */
internal class ScanRunner(
    private val database: MonegingDatabase,
    private val photoFiles: PhotoFiles,
    private val scanning: Scanning,
    private val context: CoroutineContext,
    private val now: () -> Instant,
) {
    private val scope = CoroutineScope(SupervisorJob() + context)

    /** The method a scan reads by when none is given: the one the user chose. */
    val chosenMethod: ReadingMethod
        get() = scanning.readingMethods.chosen

    /** Fails every job left queued or running, as when the app ended while it ran. */
    fun failCutOffJobs() {
        database.scansQueries.failUnfinishedScanJobs(reason = CUT_OFF, updatedAt = now().toColumn())
    }

    /** Runs the job [jobId] of the ledger [ledgerId], reading the photo [photoId] by [method]. */
    fun run(
        ledgerId: Uuid,
        jobId: Uuid,
        photoId: Uuid,
        method: ReadingMethod,
    ) {
        val rows = LedgerRows(ledgerId = ledgerId, database = database, now = now, context = context)
        scope.launch {
            scanning.pacer.awaitMove()
            move(jobId = jobId, state = ScanState.RUNNING, failureReason = null)
            val reading = read(jobId = jobId, photoId = photoId, method = method)
            scanning.pacer.awaitMove()
            reading.fold(
                onSuccess = { read ->
                    succeed(
                        rows = rows,
                        job = RunningJob(id = jobId, photoId = photoId, method = method),
                        reading = read,
                    )
                },
                onFailure = { move(jobId = jobId, state = ScanState.FAILED, failureReason = it.message ?: UNREADABLE) },
            )
        }
    }

    // What the scanner reads from the photo, or why it could not; the text it
    // recognised is kept on the job [jobId], whether or not it is read.
    private suspend fun read(
        jobId: Uuid,
        photoId: Uuid,
        method: ReadingMethod,
    ): Result<ReceiptReading> {
        val bytes = withContext(context) { photoFiles.read(photoId) } ?: return unread(PHOTO_GONE)
        return try {
            withTimeout(SCAN_DEADLINE) {
                Result.success(
                    scanning.scanner.read(image = bytes, method = method) { text ->
                        withContext(
                            context,
                        ) { database.scansQueries.keepRecognizedText(text = text, id = jobId.toString()) }
                    },
                )
            }
        } catch (late: TimeoutCancellationException) {
            unread(DEADLINE_PASSED, cause = late)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (unreadable: IllegalStateException) {
            unread(unreadable.message ?: UNREADABLE)
        } catch (malformed: IllegalArgumentException) {
            unread(malformed.message ?: UNREADABLE)
        }
    }

    private suspend fun move(
        jobId: Uuid,
        state: ScanState,
        failureReason: String?,
    ) {
        withContext(context) {
            database.scansQueries.moveScanJob(
                state = state.name,
                draftId = null,
                failureReason = failureReason,
                updatedAt = now().toColumn(),
                id = jobId.toString(),
            )
        }
    }

    // Keeps the reading as a draft and moves the job to succeeded, at once;
    // a reading that makes no draft (no amount at all) fails the job.
    private suspend fun succeed(
        rows: LedgerRows,
        job: RunningJob,
        reading: ReceiptReading,
    ) {
        val refusal =
            withContext(context) {
                try {
                    database.transaction {
                        val draftId =
                            insertDraft(rows = rows, photoId = job.photoId, reading = reading, method = job.method)
                        database.scansQueries.moveScanJob(
                            state = ScanState.SUCCEEDED.name,
                            draftId = draftId.toString(),
                            failureReason = null,
                            updatedAt = now().toColumn(),
                            id = job.id.toString(),
                        )
                    }
                    null
                } catch (unreadable: IllegalStateException) {
                    unreadable.message ?: UNREADABLE
                }
            }
        if (refusal != null) move(jobId = job.id, state = ScanState.FAILED, failureReason = refusal)
    }
}

// A job being run: [id], reading the photo [photoId] by [method].
private data class RunningJob(
    val id: Uuid,
    val photoId: Uuid,
    val method: ReadingMethod,
)

internal fun unread(
    reason: String,
    cause: Throwable? = null,
): Result<ReceiptReading> = Result.failure(IllegalStateException(reason, cause))

// Keeps [reading] of the photo [photoId] as a draft of [rows]' ledger:
// category names become the ledger's active categories of that name (none
// when it has none), a date not read is the photo's capture date and a total
// not read the items' sum, both with the confidence 0. The draft records
// the [method] it was read by.
internal fun insertDraft(
    rows: LedgerRows,
    photoId: Uuid,
    reading: ReceiptReading,
    method: ReadingMethod,
): Uuid {
    val livePhoto = rows.database.photosQueries.livePhoto(ledger_id = rows.ledgerKey, id = photoId.toString())
    val photo = checkNotNull(livePhoto.executeAsOneOrNull()) { PHOTO_GONE }
    val categories =
        rows.database.categoriesQueries
            .liveCategories(rows.ledgerKey)
            .executeAsList()
            .map { it.toDomain() }
            .filter { !it.isArchived }
    val items =
        reading.items.map { item ->
            DraftItem(
                name = item.name,
                amount = item.amount,
                categoryId = item.category?.let { name -> categories.firstOrNull { it.name == name }?.id },
                confidence = item.confidence,
            )
        }
    val total = reading.total.value ?: items.takeIf { it.isNotEmpty() }?.sumOf { it.amount }
    checkNotNull(total) { NOTHING_READ }
    val date =
        reading.date.value ?: photo.captured_at
            .toInstant()
            .toLocalDateTime(PRODUCT_TIME_ZONE)
            .date
    val now = rows.now().toColumn()
    val id = Uuid.random()
    rows.database.scansQueries.insertDraft(
        id = id.toString(),
        ledger_id = rows.ledgerKey,
        photo_id = photoId.toString(),
        store = reading.store.value,
        store_confidence = reading.store.confidence,
        date = date.toString(),
        date_confidence = if (reading.date.value != null) reading.date.confidence else 0.0,
        total = total,
        total_confidence = if (reading.total.value != null) reading.total.confidence else 0.0,
        category_id = null,
        created_at = now,
        updated_at = now,
        method = method.name,
    )
    insertDraftItems(rows = rows, draftId = id, items = items)
    return id
}

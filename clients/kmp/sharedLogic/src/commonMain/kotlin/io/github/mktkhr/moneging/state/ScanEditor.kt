package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.AmountText
import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.DraftCategory
import io.github.mktkhr.moneging.scan.DraftCorrection
import io.github.mktkhr.moneging.scan.DraftItem
import io.github.mktkhr.moneging.scan.ReadingMethod
import io.github.mktkhr.moneging.scan.ReadingMethods
import kotlinx.coroutines.CancellationException
import kotlinx.datetime.LocalDate
import kotlin.time.Clock
import kotlin.uuid.Uuid

private const val SAVE_FAILED = "保存できませんでした"
private const val NO_LEDGER = "家計簿がありません"
private const val JOB_NOT_FOUND = "読み取りが見つかりません"

// The confidence below which a draft's field is marked 要確認 (PRODUCT.md §5, Receipt reading).
private const val REVIEW_THRESHOLD = 0.6

/** Whether a field read with [confidence] is marked 要確認: below 0.6. */
fun needsReview(confidence: Double): Boolean = confidence < REVIEW_THRESHOLD

/** One item of a draft as its form holds it. */
data class DraftItemForm(
    /** Its name (品名). */
    val name: String,
    /** Its amount as typed (金額). */
    val amountText: String,
    /** Its category (`Category.id` as text), or `null` for none (その他). */
    val categoryId: String?,
    /** The scanner's confidence in it; 1 once the user changed it. */
    val confidence: Double,
)

/** A draft as its form holds it, with how sure the scanner was of each field (1 once the user changed it). */
data class DraftForm(
    /** The store name (店名). */
    val store: String,
    /** The scanner's confidence in [store]. */
    val storeConfidence: Double,
    /** The date, ISO (`2026-02-14`). */
    val date: String,
    /** The scanner's confidence in [date]. */
    val dateConfidence: Double,
    /** The total as typed (合計). */
    val totalText: String,
    /** The scanner's confidence in the total. */
    val totalConfidence: Double,
    /** The whole expense's category when there are no items (`Category.id` as text), or `null` for その他. */
    val categoryId: String?,
    /** The items. */
    val items: List<DraftItemForm>,
)

/** A draft opened to be corrected and confirmed. */
data class DraftEditing(
    /** The draft's id, as text. */
    val draftId: String,
    /** The photo it was read from, as text. */
    val photoId: String,
    /** What its form starts with. */
    val form: DraftForm,
    /** How it was read (`AI を使わずに読み取りました`), or `null` for a draft from before the reading method. */
    val methodText: String?,
)

/** What accepting photos for reading did. */
data class ScanAcceptance(
    /** How many photos were kept and their scans started. */
    val acceptedCount: Int,
    /** The notice to show (`2枚の読み取りを受け付けました`), or `null` when none was accepted. */
    val noticeText: String?,
    /** Why a photo was refused, or `null`. */
    val failureMessage: String?,
)

/**
 * The scan writes of the ledger in view ([AppState]) its screens make:
 * accepting photos, correcting, confirming and discarding drafts, reading a
 * photo again. Each returns `null` when it is done, or the reason it was
 * refused.
 */
class ScanEditor internal constructor(
    private val store: LocalStore,
    private val appState: AppState,
    private val clock: Clock,
) {
    /**
     * Keeps every photo of [images] as it is ([contentType]) and starts its
     * scan by [method], or by the method the user chose when `null`, without
     * waiting for any reading.
     */
    @Throws(Exception::class)
    suspend fun acceptPhotos(
        images: List<ByteArray>,
        contentType: String,
        method: ReadingMethod? = null,
    ): ScanAcceptance {
        val scope =
            scopeInView() ?: return ScanAcceptance(acceptedCount = 0, noticeText = null, failureMessage = NO_LEDGER)
        var accepted = 0
        val refusal =
            attempt(scope) {
                images.forEach { image ->
                    val photo = addPhoto(bytes = image, contentType = contentType, capturedAt = clock.now())
                    startScan(photoId = photo.id, method = method)
                    accepted += 1
                }
            }
        return ScanAcceptance(
            acceptedCount = accepted,
            noticeText = scanAcceptedNotice(count = accepted).takeIf { accepted > 0 },
            failureMessage = refusal,
        )
    }

    /** The waiting draft [draftId] of the ledger in view as its form opens it, or `null` when it is gone. */
    @Throws(Exception::class)
    suspend fun openDraft(draftId: String): DraftEditing? =
        scopeInView()?.findDraft(Uuid.parse(draftId))?.toEditing(readingMethods = store.readingMethods)

    /** Saves [form] into the draft [draftId] and confirms it into an expense. */
    @Throws(Exception::class)
    suspend fun confirmDraft(
        draftId: String,
        form: DraftForm,
    ): String? =
        attemptInView {
            val id = Uuid.parse(draftId)
            updateDraft(draftId = id, correction = form.toCorrection())
            confirmDraft(draftId = id)
        }

    /** Discards the draft [draftId]. */
    @Throws(Exception::class)
    suspend fun discardDraft(draftId: String): String? = attemptInView { discardDraft(draftId = Uuid.parse(draftId)) }

    /** Reads again the photo of the failed scan [jobId], by the method it was read by. */
    @Throws(Exception::class)
    suspend fun readAgain(jobId: String): String? =
        attemptInView {
            val job = requireNotNull(findScanJob(Uuid.parse(jobId))) { JOB_NOT_FOUND }
            startScan(photoId = job.photoId, method = job.method)
        }

    /** Reads again the photo of the failed scan [jobId] without AI (`AI を使わずに読む`). */
    @Throws(Exception::class)
    suspend fun readWithoutAi(jobId: String): String? =
        attemptInView {
            val job = requireNotNull(findScanJob(Uuid.parse(jobId))) { JOB_NOT_FOUND }
            startScan(photoId = job.photoId, method = ReadingMethod.NO_AI)
        }

    /**
     * The text recognised for the scan job or draft [scanId] of the ledger
     * in view, or `null` when none was kept.
     */
    @Throws(Exception::class)
    suspend fun recognizedText(scanId: String): String? = scopeInView()?.recognizedText(scanId = Uuid.parse(scanId))

    /** The bytes of the photo [photoId] of the ledger in view, or `null`. */
    @Throws(Exception::class)
    suspend fun photoBytes(photoId: String): ByteArray? = scopeInView()?.photoBytes(Uuid.parse(photoId))

    private fun scopeInView(): LedgerScope? =
        appState.uiState.value.selectedLedgerId
            ?.let { store.ledger(Uuid.parse(it)) }

    private suspend fun attemptInView(write: suspend LedgerScope.() -> Any): String? {
        val scope = scopeInView() ?: return NO_LEDGER
        return attempt(scope, write)
    }

    private suspend fun attempt(
        scope: LedgerScope,
        write: suspend LedgerScope.() -> Any,
    ): String? =
        try {
            scope.write()
            null
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (refused: IllegalArgumentException) {
            refused.message ?: SAVE_FAILED
        } catch (expected: IllegalStateException) {
            expected.message ?: SAVE_FAILED
        }
}

internal fun Draft.toEditing(readingMethods: ReadingMethods): DraftEditing =
    DraftEditing(
        draftId = id.toString(),
        photoId = photoId.toString(),
        methodText = method?.let(readingMethods::readText),
        form =
            DraftForm(
                store = store.value,
                storeConfidence = store.confidence,
                date = date.value.toString(),
                dateConfidence = date.confidence,
                totalText = AmountText.grouped(total.value.toString()),
                totalConfidence = total.confidence,
                categoryId = categoryId?.toString(),
                items =
                    items.map { item ->
                        DraftItemForm(
                            name = item.name,
                            amountText = AmountText.grouped(item.amount.toString()),
                            categoryId = item.categoryId?.toString(),
                            confidence = item.confidence,
                        )
                    },
            ),
    )

internal fun DraftForm.toCorrection(): DraftCorrection =
    DraftCorrection(
        store = store.trim(),
        date = LocalDate.parse(date),
        total = AmountText.parse(totalText),
        category = DraftCategory(id = categoryId?.let { Uuid.parse(it) }),
        items =
            items.map { item ->
                DraftItem(
                    name = item.name.trim(),
                    amount = AmountText.parseSigned(item.amountText),
                    categoryId = item.categoryId?.let { Uuid.parse(it) },
                    confidence = item.confidence,
                )
            },
    )

package io.github.mktkhr.moneging.scan

import kotlinx.datetime.LocalDate
import kotlin.time.Instant
import kotlin.uuid.Uuid

/** Where a scan job stands (PRODUCT.md §3, Scan job); it only ever moves forward, in this order. */
enum class ScanState {
    /** Waiting to be read. */
    QUEUED,

    /** Being read. */
    RUNNING,

    /** Read into a draft. */
    SUCCEEDED,

    /** Not read; the job carries why. */
    FAILED,
    ;

    /** Whether the job is still in flight (queued or running). */
    val isInFlight: Boolean
        get() = this == QUEUED || this == RUNNING
}

/** The reading of one photo, in the background. */
data class ScanJob(
    /** Its identifier. */
    val id: Uuid,
    /** The ledger it belongs to. */
    val ledgerId: Uuid,
    /** The photo it reads. */
    val photoId: Uuid,
    /** Where it stands. */
    val state: ScanState,
    /** The draft it produced, once [ScanState.SUCCEEDED]. */
    val draftId: Uuid?,
    /** Why it failed, once [ScanState.FAILED]: human-readable. */
    val failureReason: String?,
    /** When it was started. */
    val createdAt: Instant,
    /** When it last moved. */
    val updatedAt: Instant,
)

/** A value the scanner read, with how sure it is of it (0 to 1). */
data class ScannedValue<T>(
    /** The value. */
    val value: T,
    /** The scanner's confidence, from 0 to 1. */
    val confidence: Double,
)

/** One item of a draft. */
data class DraftItem(
    /** Its name as read (品名). */
    val name: String,
    /** Its amount in yen. */
    val amount: Long,
    /** Its category in the draft's ledger, or `null` for none (confirmed into その他). */
    val categoryId: Uuid?,
    /** The scanner's confidence in the item. */
    val confidence: Double,
)

/** The result of a succeeded scan, waiting to be confirmed or discarded (PRODUCT.md §3, Draft). */
data class Draft(
    /** Its identifier. */
    val id: Uuid,
    /** The ledger it belongs to. */
    val ledgerId: Uuid,
    /** The photo it was read from. */
    val photoId: Uuid,
    /** The store name (店名). */
    val store: ScannedValue<String>,
    /** The date (日付). */
    val date: ScannedValue<LocalDate>,
    /** The total (合計), in yen. */
    val total: ScannedValue<Long>,
    /** The category of the whole expense when it has no items; `null` for none (その他). */
    val categoryId: Uuid?,
    /** Its items, in the receipt's order. */
    val items: List<DraftItem>,
    /** When it was read. */
    val createdAt: Instant,
    /** When it was last corrected. */
    val updatedAt: Instant,
)

/** The whole-expense category a correction sets: [id], or `null` for none. */
data class DraftCategory(
    /** The category, or `null` for none (その他). */
    val id: Uuid?,
)

/**
 * Corrections to a draft: each field given replaces the draft's, each one
 * left `null` stays as it is. A corrected store, date or total is the user's
 * reading, so its confidence becomes 1; [items] replace the draft's items as
 * a whole, as given.
 */
data class DraftCorrection(
    /** The store name. */
    val store: String? = null,
    /** The date. */
    val date: LocalDate? = null,
    /** The total, in yen. */
    val total: Long? = null,
    /** The whole-expense category. */
    val category: DraftCategory? = null,
    /** The items. */
    val items: List<DraftItem>? = null,
)

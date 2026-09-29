package io.github.mktkhr.moneging.domain

import kotlin.time.Instant
import kotlin.uuid.Uuid

/**
 * A book of money on the device (PRODUCT.md §3). Every other record belongs
 * to exactly one ledger.
 */
data class Ledger(
    override val id: Uuid,
    /** The name the user gave it: trimmed, 1 to 20 characters ([LedgerName]). */
    val name: String,
    override val createdAt: Instant,
    override val updatedAt: Instant,
) : SyncRecord

/** A bucket for spending, scoped to one ledger. */
data class Category(
    override val id: Uuid,
    /** The ledger it belongs to. */
    val ledgerId: Uuid,
    /** The name shown for it. */
    val name: String,
    /** Whether it is archived: it keeps its history but takes no new transactions. */
    val isArchived: Boolean,
    override val createdAt: Instant,
    override val updatedAt: Instant,
) : SyncRecord

/** An image belonging to a ledger; its bytes live in the app's private storage. */
data class Photo(
    override val id: Uuid,
    /** The ledger it belongs to. */
    val ledgerId: Uuid,
    /** The media type of its bytes, e.g. `image/jpeg`. */
    val contentType: String,
    /** The size of its bytes. */
    val sizeBytes: Long,
    /** When it was captured. */
    val capturedAt: Instant,
    override val createdAt: Instant,
    override val updatedAt: Instant,
) : SyncRecord

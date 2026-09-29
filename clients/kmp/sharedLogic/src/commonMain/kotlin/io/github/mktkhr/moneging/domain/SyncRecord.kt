package io.github.mktkhr.moneging.domain

import kotlin.time.Instant
import kotlin.uuid.Uuid

/**
 * A record that v2 can sync without changing identifiers (PRODUCT.md §6,
 * sync-ready data): a UUID generated on the device, and the instants it was
 * created and last updated.
 */
interface SyncRecord {
    /** The identifier generated on the device when the record was created. */
    val id: Uuid

    /** When the record was created; never changes. */
    val createdAt: Instant

    /** When the record was last changed; equals [createdAt] until then. */
    val updatedAt: Instant
}

/** A record as the database holds it, deleted or not. */
data class StoredRecord<out T : SyncRecord>(
    /** The record, as it was when it was deleted if it is a tombstone. */
    val record: T,
    /** When the record was deleted; `null` for a live record. */
    val deletedAt: Instant?,
)

/** The whole database, tombstones included: what sync and backup read. */
data class RecordSnapshot(
    /** Every ledger. */
    val ledgers: List<StoredRecord<Ledger>>,
    /** Every category of every ledger. */
    val categories: List<StoredRecord<Category>>,
    /** Every transaction; a tombstone keeps its items in `record.items`. */
    val transactions: List<StoredRecord<Transaction>>,
    /** Every photo record. */
    val photos: List<StoredRecord<Photo>>,
    /** Every budget. */
    val budgets: List<StoredRecord<Budget>>,
    /** Every recurring rule. */
    val recurringRules: List<StoredRecord<RecurringRule>>,
)

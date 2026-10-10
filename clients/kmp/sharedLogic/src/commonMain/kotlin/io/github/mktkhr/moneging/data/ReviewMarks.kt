package io.github.mktkhr.moneging.data

import kotlin.uuid.Uuid

/**
 * Marks the transaction [transactionId] of the ledger [ledgerId]
 * needs-review, as confirming a draft with its mismatch accepted does; for
 * the records a test starts with (the UI tests' only in debug builds).
 */
internal fun LocalStore.markReviewNeeded(
    ledgerId: Uuid,
    transactionId: Uuid,
) {
    database.transactionsQueries.markReviewNeeded(ledger_id = ledgerId.toString(), id = transactionId.toString())
}

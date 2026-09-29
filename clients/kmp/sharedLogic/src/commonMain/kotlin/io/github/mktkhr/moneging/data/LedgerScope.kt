package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.Budget
import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.MonthTotals
import io.github.mktkhr.moneging.domain.NewRecurringRule
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Photo
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.datetime.YearMonth
import kotlin.time.Instant
import kotlin.uuid.Uuid

/**
 * Every operation within one ledger (isolation, PRODUCT.md §6): reads
 * return only this ledger's records, and a write that names another
 * ledger's category or photo is refused with [IllegalArgumentException],
 * writing nothing.
 */
interface LedgerScope :
    LedgerCategories,
    LedgerPhotos,
    LedgerTransactionReads,
    LedgerTransactionWrites,
    LedgerPlans {
    /** The ledger these operations act within. */
    val ledgerId: Uuid
}

/** A ledger's categories. */
interface LedgerCategories {
    /** This ledger's categories: the defaults in their fixed order, then the added ones. */
    suspend fun categories(): List<Category>

    /** This ledger's category [id]; `null` for another ledger's. */
    suspend fun findCategory(id: Uuid): Category?

    /** Adds a category named [name] (trimmed, not empty). */
    suspend fun createCategory(name: String): Category
}

/** A ledger's photos. */
interface LedgerPhotos {
    /** Keeps a photo's [bytes] with this ledger. */
    suspend fun addPhoto(
        bytes: ByteArray,
        contentType: String,
        capturedAt: Instant,
    ): Photo

    /** This ledger's photo [id]; `null` for another ledger's. */
    suspend fun findPhoto(id: Uuid): Photo?
}

/** Reading a ledger's transactions; deleted ones are never found, listed or counted. */
interface LedgerTransactionReads {
    /** This ledger's transaction [id]; `null` when it is deleted or another ledger's. */
    suspend fun findTransaction(id: Uuid): Transaction?

    /** The live transactions dated in [month], newest first. */
    suspend fun transactions(month: YearMonth): List<Transaction>

    /** The totals of the live transactions dated in [month]. */
    suspend fun monthTotals(month: YearMonth): MonthTotals
}

/** Writing a ledger's transactions. */
interface LedgerTransactionWrites {
    /** Records [transaction], stamped with this device's identifier. */
    suspend fun recordTransaction(transaction: NewTransaction): Transaction

    /** Changes the memo of the transaction [transactionId]. */
    suspend fun updateMemo(
        transactionId: Uuid,
        memo: String?,
    ): Transaction

    /** Deletes the transaction [transactionId], leaving a tombstone with its items. */
    suspend fun deleteTransaction(transactionId: Uuid)
}

/** A ledger's budgets and recurring rules. */
interface LedgerPlans {
    /** Sets a budget of [amount] for [categoryId] (`null`: the whole month) from the month [from] on. */
    suspend fun setBudget(
        categoryId: Uuid?,
        amount: Long,
        from: YearMonth,
    ): Budget

    /** Creates a recurring rule. */
    suspend fun createRecurringRule(rule: NewRecurringRule): RecurringRule
}

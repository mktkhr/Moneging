package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.Budget
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.DailyTotal
import io.github.mktkhr.moneging.domain.MonthBudgets
import io.github.mktkhr.moneging.domain.MonthClose
import io.github.mktkhr.moneging.domain.MonthTotals
import io.github.mktkhr.moneging.domain.MonthlyReport
import io.github.mktkhr.moneging.domain.MonthlyTotal
import io.github.mktkhr.moneging.domain.NewRecurringRule
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Photo
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.Savings
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.domain.TransactionQuery
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
    LedgerReports,
    LedgerTransactionWrites,
    LedgerPlans,
    LedgerMonthCloses,
    LedgerRecurringRules {
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

    /** Renames this ledger's category [categoryId] to [name] (trimmed, not empty). */
    suspend fun renameCategory(
        categoryId: Uuid,
        name: String,
    ): Category

    /** Archives this ledger's category [categoryId]: it keeps its history but takes no new transactions. */
    suspend fun archiveCategory(categoryId: Uuid): Category
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

    /** The live transactions matching every condition of [query], newest first. */
    suspend fun searchTransactions(query: TransactionQuery): List<Transaction>
}

/**
 * A ledger's reports (PRODUCT.md §2): spending only, from live transactions,
 * a split transaction's items each counted in their own category; income
 * never counts.
 */
interface LedgerReports {
    /** The spending of [month] by category, largest first, and its total. */
    suspend fun monthlyReport(month: YearMonth): MonthlyReport

    /** The spending of every day of [month], in date order, 0 for a day without any. */
    suspend fun dailyTotals(month: YearMonth): List<DailyTotal>

    /** The spending of the twelve months ending with [to], oldest first, 0 for a month without any. */
    suspend fun monthlyTrend(to: YearMonth): List<MonthlyTotal>
}

/** Writing a ledger's transactions. */
interface LedgerTransactionWrites {
    /** Records [transaction], stamped with this device's identifier. */
    suspend fun recordTransaction(transaction: NewTransaction): Transaction

    /**
     * Replaces the content of the transaction [transactionId] with
     * [transaction], its items as a whole; keeps its identifier, creation,
     * device and recurring rule.
     */
    suspend fun updateTransaction(
        transactionId: Uuid,
        transaction: NewTransaction,
    ): Transaction

    /** Changes the memo of the transaction [transactionId]. */
    suspend fun updateMemo(
        transactionId: Uuid,
        memo: String?,
    ): Transaction

    /** Deletes the transaction [transactionId], leaving a tombstone with its items. */
    suspend fun deleteTransaction(transactionId: Uuid)
}

/**
 * A ledger's budgets (PRODUCT.md §3, Budget). A budget set or removed from a
 * month on holds for every later month until another is set or removed; a
 * write from a month that is closed, or before one, is refused with
 * [IllegalStateException] (a closed month's budgets are final).
 */
interface LedgerPlans {
    /** Sets a budget of [amount] for [categoryId] (`null`: the whole month) from the month [from] on. */
    suspend fun setBudget(
        categoryId: Uuid?,
        amount: Long,
        from: YearMonth,
    ): Budget

    /** Removes the budget of [categoryId] (`null`: the whole month) from the month [from] on. */
    suspend fun removeBudget(
        categoryId: Uuid?,
        from: YearMonth,
    ): Budget

    /**
     * The budgets of [month]: the whole month's, then every category with a
     * budget or with spending, in category order, each with what was
     * carried in, spent and left.
     */
    suspend fun budgetRemaining(month: YearMonth): MonthBudgets
}

/**
 * Closing a ledger's months (PRODUCT.md §3, Carry-over policy) and its
 * savings. A refused close throws [IllegalStateException].
 */
interface LedgerMonthCloses {
    /** The ledger's carry-over policy: [CarryOverPolicy.CARRY] until changed. */
    suspend fun carryOverPolicy(): CarryOverPolicy

    /** Changes the ledger's carry-over policy; closed months keep theirs. */
    suspend fun setCarryOverPolicy(policy: CarryOverPolicy)

    /**
     * Closes [month] under the ledger's policy, once: a month closed already
     * is not closed again, and its first close is reported. Refused while
     * the month has not ended (Asia/Tokyo), and while an earlier month that
     * has a budget is open.
     */
    suspend fun closeMonth(month: YearMonth): MonthClose

    /** Whether [month] is closed. */
    suspend fun isMonthClosed(month: YearMonth): Boolean

    /** The earliest month that has ended, has a budget and is open: the one to offer closing; `null` for none. */
    suspend fun monthToClose(): YearMonth?

    /** The ledger's savings. */
    suspend fun savings(): Savings
}

/** A ledger's recurring rules, and the transactions they record. */
interface LedgerRecurringRules {
    /** Creates a recurring rule; it records nothing until [materializeRecurringRules] runs. */
    suspend fun createRecurringRule(rule: NewRecurringRule): RecurringRule

    /** This ledger's live recurring rules, in creation order. */
    suspend fun recurringRules(): List<RecurringRule>

    /**
     * Replaces the content of the rule [ruleId]; the transactions it recorded
     * stay as they are. Clearing or moving later the end month of an ended
     * rule resumes it: the months whose date came while it was ended are
     * never recorded.
     */
    suspend fun updateRecurringRule(
        ruleId: Uuid,
        rule: NewRecurringRule,
    ): RecurringRule

    /**
     * Ends the rule [ruleId]: its end month becomes the last month it
     * recorded (deleted transactions included), so nothing more is recorded.
     * A rule that recorded nothing ends the month before its start.
     */
    suspend fun endRecurringRule(ruleId: Uuid): RecurringRule

    /** Deletes the rule [ruleId]; the transactions it recorded stay and still name it. */
    suspend fun deleteRecurringRule(ruleId: Uuid)

    /**
     * Records every month of every live rule whose date has come (today in
     * Asia/Tokyo, by the injected clock) and that is not recorded yet, once
     * per rule and month however often it runs; a month whose transaction
     * was deleted stays done. Returns what it recorded.
     */
    suspend fun materializeRecurringRules(): List<Transaction>
}

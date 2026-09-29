package io.github.mktkhr.moneging.domain

import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.time.Instant
import kotlin.uuid.Uuid

/** Which way money moves. */
enum class Direction {
    /** Money spent (支出). */
    EXPENSE,

    /** Money received (収入). */
    INCOME,
}

/** One part of a split transaction. */
data class LineItem(
    override val id: Uuid,
    /** Its amount in yen, at least 1. */
    val amount: Long,
    /** Its category, in the transaction's ledger. */
    val categoryId: Uuid,
    /** Its item name, if any. */
    val name: String?,
    override val createdAt: Instant,
    override val updatedAt: Instant,
) : SyncRecord

/** One movement of money on one date (PRODUCT.md §3). */
data class Transaction(
    override val id: Uuid,
    /** The ledger it belongs to. */
    val ledgerId: Uuid,
    /** The calendar date it happened on. */
    val date: LocalDate,
    /** Expense or income. */
    val direction: Direction,
    /** Its amount in yen; the sum of [items] when it is split. */
    val amount: Long,
    /** Its category; `null` when it is split into [items]. */
    val categoryId: Uuid?,
    /** An optional memo. */
    val memo: String?,
    /** An optional store name. */
    val storeName: String?,
    /** The photo it is linked to, if any. */
    val photoId: Uuid?,
    /** Its line items, in order; empty when it is not split. */
    val items: List<LineItem>,
    /** The identifier of the device it was recorded on. */
    val deviceId: String,
    override val createdAt: Instant,
    override val updatedAt: Instant,
) : SyncRecord

/** A planned amount for a ledger, optionally for one category, from a month on. */
data class Budget(
    override val id: Uuid,
    /** The ledger it belongs to. */
    val ledgerId: Uuid,
    /** Its category; `null` for the whole-month budget. */
    val categoryId: Uuid?,
    /** The planned amount in yen. */
    val amount: Long,
    /** The first month it applies to. */
    val fromMonth: YearMonth,
    override val createdAt: Instant,
    override val updatedAt: Instant,
) : SyncRecord

/** A transaction that repeats monthly on a day of the month. */
data class RecurringRule(
    override val id: Uuid,
    /** The ledger it belongs to. */
    val ledgerId: Uuid,
    /** Expense or income. */
    val direction: Direction,
    /** Its amount in yen. */
    val amount: Long,
    /** Its category. */
    val categoryId: Uuid,
    /** The day of the month it falls on, 1 to 31. */
    val dayOfMonth: Int,
    /** The first month it applies to. */
    val startMonth: YearMonth,
    /** The last month it applies to, or `null` for no end. */
    val endMonth: YearMonth?,
    /** An optional memo. */
    val memo: String?,
    override val createdAt: Instant,
    override val updatedAt: Instant,
) : SyncRecord

/** A line item to record. */
data class NewLineItem(
    /** Its amount in yen, at least 1. */
    val amount: Long,
    /** Its category, in the ledger it is recorded in. */
    val categoryId: Uuid,
    /** Its item name, if any. */
    val name: String? = null,
)

/** A transaction to record. */
data class NewTransaction(
    /** The calendar date it happened on. */
    val date: LocalDate,
    /** Expense or income. */
    val direction: Direction,
    /** Its amount in yen; with [items], it must equal their sum. */
    val amount: Long,
    /** Its category: required without [items], `null` with them. */
    val categoryId: Uuid?,
    /** An optional memo. */
    val memo: String? = null,
    /** An optional store name. */
    val storeName: String? = null,
    /** A photo of the same ledger to link, if any. */
    val photoId: Uuid? = null,
    /** Its line items; empty for an unsplit transaction. */
    val items: List<NewLineItem> = emptyList(),
)

/** A recurring rule to create. */
data class NewRecurringRule(
    /** Expense or income. */
    val direction: Direction,
    /** Its amount in yen, at least 1. */
    val amount: Long,
    /** Its category, in the ledger it is created in. */
    val categoryId: Uuid,
    /** The day of the month it falls on, 1 to 31. */
    val dayOfMonth: Int,
    /** The first month it applies to. */
    val startMonth: YearMonth,
    /** The last month it applies to, or `null` for no end. */
    val endMonth: YearMonth? = null,
    /** An optional memo. */
    val memo: String? = null,
)

/** A month's totals of live transactions, in yen. */
data class MonthTotals(
    /** The sum of expenses. */
    val expense: Long,
    /** The sum of income. */
    val income: Long,
)

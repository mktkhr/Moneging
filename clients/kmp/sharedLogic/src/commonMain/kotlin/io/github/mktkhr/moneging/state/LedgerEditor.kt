package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.AmountText
import io.github.mktkhr.moneging.domain.BusinessDayAdjustment
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewRecurringRule
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.domain.TransactionQuery
import kotlinx.coroutines.CancellationException
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

private const val SAVE_FAILED = "保存できませんでした"

/** A line item as the entry form holds it. */
data class LineItemDraft(
    /** Its item name, blank for none. */
    val name: String,
    /** Its category (`Category.id` as text), `null` when none is chosen yet. */
    val categoryId: String?,
    /** Its amount as typed. */
    val amountText: String,
)

/** A transaction as the entry form holds it; [LedgerEditor] reads it into a record. */
data class TransactionDraft(
    /** Its date, ISO (`2026-02-15`). */
    val date: String,
    /** Whether it is an income (収入) rather than an expense (支出). */
    val isIncome: Boolean,
    /** Its amount as typed; ignored when it has [items], whose sum it is. */
    val amountText: String,
    /** Its category (`Category.id` as text): an unsplit expense's, else `null`. */
    val categoryId: String?,
    /** Its store name, blank for none. */
    val storeName: String,
    /** Its memo, blank for none. */
    val memo: String,
    /** Its line items; empty when it is not split. */
    val items: List<LineItemDraft>,
    /** The photo it is linked to (`Photo.id` as text), or `null`. */
    val photoId: String?,
)

/** A recurring rule as the rule form holds it. */
data class RecurringRuleDraft(
    /** Whether it is an income rather than an expense. */
    val isIncome: Boolean,
    /** Its amount as typed. */
    val amountText: String,
    /** Its category (`Category.id` as text): an expense's, `null` for an income. */
    val categoryId: String?,
    /** Its day of the month as typed, or `null` for the month's last day (月末). */
    val dayText: String?,
    /** Where its date moves when it is not a business day. */
    val adjustment: BusinessDayAdjustment,
    /** The first month, ISO (`2026-02`). */
    val startMonth: String,
    /** The last month, ISO, or `null` for no end. */
    val endMonth: String?,
    /** Its memo, blank for none. */
    val memo: String,
)

/** A search as the search screen holds it. */
data class SearchDraft(
    /** Text to find in the memo, the store name or an item name; blank for any. */
    val text: String,
    /** The month searched, ISO (`2026-02`), or `null` for every period. */
    val month: String?,
    /** The category (`Category.id` as text), or `null` for any. */
    val categoryId: String?,
    /** The least amount, or `null`. */
    val minAmount: Long?,
    /** The greatest amount, or `null`. */
    val maxAmount: Long?,
)

/**
 * The writes of the ledger in view ([AppState]) its screens make, from
 * what the forms hold. Each returns `null` when it is done, or the reason
 * it was refused, to be shown to the user; nothing is written when it is
 * refused. The records they change reach the screens through [LedgerData].
 */
class LedgerEditor internal constructor(
    private val store: LocalStore,
    private val appState: AppState,
    ledgerData: LedgerData,
) {
    /** The writes of the recurring rules of the ledger in view. */
    val recurringRules: RecurringRuleEditor =
        RecurringRuleEditor(ledgerData = ledgerData) { write -> attempt(write) }

    /** The writes of the budgets and the month closes of the ledger in view. */
    val budgets: BudgetEditor = BudgetEditor { write -> attempt(write) }

    /** Records [draft] in the ledger in view. */
    @Throws(Exception::class)
    suspend fun recordTransaction(draft: TransactionDraft): String? =
        attempt { recordTransaction(transaction = draft.toNewTransaction()) }

    /**
     * Replaces the transaction [transactionId] with [draft]; a needs-review
     * mark stays while it keeps its `差額` item.
     */
    @Throws(Exception::class)
    suspend fun updateTransaction(
        transactionId: String,
        draft: TransactionDraft,
    ): String? =
        attempt {
            val id = Uuid.parse(transactionId)
            val isMarked = findTransaction(id)?.isReviewNeeded == true
            updateTransaction(
                transactionId = id,
                transaction = draft.toNewTransaction().copy(isReviewNeeded = isMarked),
            )
        }

    /** Marks the transaction [transactionId] reviewed as it is (`このままで確認済みにする`). */
    @Throws(Exception::class)
    suspend fun markReviewed(transactionId: String): String? =
        attempt {
            val id = Uuid.parse(transactionId)
            val current = requireNotNull(findTransaction(id)) { "記録が見つかりません" }
            updateTransaction(transactionId = id, transaction = current.asReviewed())
        }

    /** Deletes the transaction [transactionId]. */
    @Throws(Exception::class)
    suspend fun deleteTransaction(transactionId: String): String? =
        attempt { deleteTransaction(transactionId = Uuid.parse(transactionId)) }

    /** Adds a category named [name]. */
    @Throws(Exception::class)
    suspend fun createCategory(name: String): String? = attempt { createCategory(name = name) }

    /** Renames the category [categoryId] to [name]. */
    @Throws(Exception::class)
    suspend fun renameCategory(
        categoryId: String,
        name: String,
    ): String? = attempt { renameCategory(categoryId = Uuid.parse(categoryId), name = name) }

    /** Archives the category [categoryId]. */
    @Throws(Exception::class)
    suspend fun archiveCategory(categoryId: String): String? =
        attempt { archiveCategory(categoryId = Uuid.parse(categoryId)) }

    /** The live transactions of the ledger in view matching [draft], every period included unless it names one. */
    @Throws(Exception::class)
    suspend fun search(draft: SearchDraft): List<Transaction> {
        val scope = scopeInView() ?: return emptyList()
        return scope.searchTransactions(
            query =
                TransactionQuery(
                    from = draft.month?.let { YearMonth.parse(it).firstDay },
                    to = draft.month?.let { YearMonth.parse(it).lastDay },
                    categoryId = draft.categoryId?.let { Uuid.parse(it) },
                    text = draft.text.trim().ifEmpty { null },
                    minAmount = draft.minAmount,
                    maxAmount = draft.maxAmount,
                ),
        )
    }

    private fun scopeInView(): LedgerScope? =
        appState.uiState.value.selectedLedgerId
            ?.let { store.ledger(Uuid.parse(it)) }

    // Runs [write] in the ledger in view; a refusal is returned as its reason.
    private suspend fun attempt(write: suspend LedgerScope.() -> Any): String? {
        val scope = scopeInView() ?: return "家計簿がありません"
        return try {
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
}

/**
 * The writes of the recurring rules of the ledger in view ([LedgerEditor.recurringRules]);
 * each returns `null` when it is done, or the reason it was refused.
 */
class RecurringRuleEditor internal constructor(
    private val ledgerData: LedgerData,
    private val write: suspend (suspend LedgerScope.() -> Any) -> String?,
) {
    /** Adds the recurring rule [draft], then records its months whose date has come. */
    @Throws(Exception::class)
    suspend fun createRecurringRule(draft: RecurringRuleDraft): String? {
        val refusal = write { createRecurringRule(rule = draft.toNewRecurringRule()) }
        if (refusal == null) ledgerData.materializeRecurringRules()
        return refusal
    }

    /** Replaces the recurring rule [ruleId] with [draft], then records its months whose date has come. */
    @Throws(Exception::class)
    suspend fun updateRecurringRule(
        ruleId: String,
        draft: RecurringRuleDraft,
    ): String? {
        val refusal = write { updateRecurringRule(ruleId = Uuid.parse(ruleId), rule = draft.toNewRecurringRule()) }
        if (refusal == null) ledgerData.materializeRecurringRules()
        return refusal
    }

    /** Ends the recurring rule [ruleId] with the last month it recorded. */
    @Throws(Exception::class)
    suspend fun endRecurringRule(ruleId: String): String? = write { endRecurringRule(ruleId = Uuid.parse(ruleId)) }

    /** Deletes the recurring rule [ruleId]; what it recorded stays. */
    @Throws(Exception::class)
    suspend fun deleteRecurringRule(ruleId: String): String? =
        write { deleteRecurringRule(ruleId = Uuid.parse(ruleId)) }
}

internal fun String.orNullIfBlank(): String? = trim().ifEmpty { null }

internal fun TransactionDraft.toNewTransaction(): NewTransaction {
    val lineItems =
        items.map { item ->
            NewLineItem(
                amount = AmountText.parseSigned(item.amountText),
                categoryId = Uuid.parse(requireNotNull(item.categoryId) { "明細の分類を選んでください" }),
                name = item.name.orNullIfBlank(),
            )
        }
    return NewTransaction(
        date = LocalDate.parse(date),
        direction = if (isIncome) Direction.INCOME else Direction.EXPENSE,
        amount = if (lineItems.isEmpty()) AmountText.parse(amountText) else lineItems.sumOf { it.amount },
        categoryId = categoryId?.takeIf { !isIncome && lineItems.isEmpty() }?.let { Uuid.parse(it) },
        memo = memo.orNullIfBlank(),
        storeName = storeName.orNullIfBlank(),
        photoId = photoId?.let { Uuid.parse(it) },
        items = lineItems,
    )
}

// The transaction's content as it is, unmarked.
internal fun Transaction.asReviewed(): NewTransaction =
    NewTransaction(
        date = date,
        direction = direction,
        amount = amount,
        categoryId = categoryId,
        memo = memo,
        storeName = storeName,
        photoId = photoId,
        items = items.map { NewLineItem(amount = it.amount, categoryId = it.categoryId, name = it.name) },
        isReviewNeeded = false,
    )

/** [rule] as the rule form holds it. */
internal fun RecurringRule.toDraft(): RecurringRuleDraft =
    RecurringRuleDraft(
        isIncome = direction == Direction.INCOME,
        amountText = amount.toString(),
        categoryId = categoryId?.toString(),
        dayText = dayOfMonth?.toString(),
        adjustment = adjustment,
        startMonth = startMonth.toString(),
        endMonth = endMonth?.toString(),
        memo = memo.orEmpty(),
    )

internal fun RecurringRuleDraft.toNewRecurringRule(): NewRecurringRule =
    NewRecurringRule(
        direction = if (isIncome) Direction.INCOME else Direction.EXPENSE,
        amount = AmountText.parse(amountText),
        categoryId = categoryId?.takeIf { !isIncome }?.let { Uuid.parse(it) },
        dayOfMonth = dayText?.let { AmountText.parse(it).toInt() },
        startMonth = YearMonth.parse(startMonth),
        endMonth = endMonth?.let { YearMonth.parse(it) },
        memo = memo.orNullIfBlank(),
        adjustment = adjustment,
    )

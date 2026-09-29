package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.data.db.Recurring_rules
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewRecurringRule
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.RecurringSchedule
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.coroutines.withContext
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlinx.datetime.minusMonth
import kotlinx.datetime.plusMonth
import kotlin.uuid.Uuid

private const val FIRST_DAY_OF_MONTH = 1
private const val LAST_DAY_OF_MONTH = 31
private const val RULE_NOT_FOUND = "定期が見つかりません"

/** [LedgerRecurringRules] over the database; what they record is stamped with [deviceId]. */
internal class SqlRecurringRules(
    private val rows: LedgerRows,
    private val deviceId: String,
) : LedgerRecurringRules {
    private val queries = rows.database.recurringRulesQueries

    override suspend fun createRecurringRule(rule: NewRecurringRule): RecurringRule {
        requireShape(rule)
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                rule.categoryId?.let { rows.requireActiveCategory(it) }
                val now = rows.now().toColumn()
                val id = Uuid.random()
                queries.insertRecurringRule(
                    id = id.toString(),
                    ledger_id = rows.ledgerKey,
                    direction = rule.direction.name,
                    amount = rule.amount,
                    category_id = rule.categoryId?.toString(),
                    day_of_month = rule.dayOfMonth?.toLong(),
                    start_month = rule.startMonth.toString(),
                    end_month = rule.endMonth?.toString(),
                    memo = rule.memo,
                    adjustment = rule.adjustment.name,
                    created_at = now,
                    updated_at = now,
                )
                checkNotNull(rule(id))
            }
        }
    }

    override suspend fun recurringRules(): List<RecurringRule> =
        withContext(rows.context) {
            queries.liveRecurringRules(rows.ledgerKey).executeAsList().map { it.toDomain() }
        }

    override suspend fun updateRecurringRule(
        ruleId: Uuid,
        rule: NewRecurringRule,
    ): RecurringRule {
        requireShape(rule)
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                val currentRow = requireNotNull(ruleRow(ruleId)) { RULE_NOT_FOUND }
                val current = currentRow.toDomain()
                rule.categoryId?.let { id ->
                    if (id == current.categoryId) rows.requireCategory(id) else rows.requireActiveCategory(id)
                }
                val resumed = resumedFrom(current = current, rule = rule, today = rows.today())
                if (resumed != null) {
                    val earlier = currentRow.resumed_from?.let { YearMonth.parse(it) }
                    queries.resumeRecurringRule(
                        resumedFrom = listOfNotNull(earlier, resumed).max().toString(),
                        ledgerId = rows.ledgerKey,
                        id = ruleId.toString(),
                    )
                }
                queries.updateRecurringRule(
                    direction = rule.direction.name,
                    amount = rule.amount,
                    categoryId = rule.categoryId?.toString(),
                    dayOfMonth = rule.dayOfMonth?.toLong(),
                    startMonth = rule.startMonth.toString(),
                    endMonth = rule.endMonth?.toString(),
                    memo = rule.memo,
                    adjustment = rule.adjustment.name,
                    updatedAt = rows.now().toColumn(),
                    ledgerId = rows.ledgerKey,
                    id = ruleId.toString(),
                )
                checkNotNull(rule(ruleId))
            }
        }
    }

    override suspend fun endRecurringRule(ruleId: Uuid): RecurringRule =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                val current = requireNotNull(rule(ruleId)) { RULE_NOT_FOUND }
                val lastRecorded =
                    rows.database.transactionsQueries
                        .lastRecordedMonth(ledgerId = rows.ledgerKey, ruleId = ruleId.toString())
                        .executeAsOne()
                        .month
                        ?.let { YearMonth.parse(it) }
                queries.endRecurringRule(
                    endMonth = (lastRecorded ?: current.startMonth.minusMonth()).toString(),
                    updatedAt = rows.now().toColumn(),
                    ledgerId = rows.ledgerKey,
                    id = ruleId.toString(),
                )
                checkNotNull(rule(ruleId))
            }
        }

    override suspend fun deleteRecurringRule(ruleId: Uuid): Unit =
        withContext(rows.context) {
            rows.database.transaction {
                requireNotNull(rule(ruleId)) { RULE_NOT_FOUND }
                queries.deleteRecurringRule(
                    deletedAt = rows.now().toColumn(),
                    ledgerId = rows.ledgerKey,
                    id = ruleId.toString(),
                )
            }
        }

    override suspend fun materializeRecurringRules(): List<Transaction> =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                val today = rows.today()
                queries.liveRecurringRules(rows.ledgerKey).executeAsList().flatMap { row ->
                    val rule = row.toDomain()
                    val resumedFrom = row.resumed_from?.let { YearMonth.parse(it) }
                    val isToRecord = { month: YearMonth ->
                        (resumedFrom == null || month >= resumedFrom) &&
                            !isRecorded(rule = rule, month = month.toString())
                    }
                    RecurringSchedule
                        .monthsDue(rule = rule, today = today)
                        .filter(isToRecord)
                        .map { month ->
                            insertTransaction(
                                rows = rows,
                                deviceId = deviceId,
                                transaction =
                                    NewTransaction(
                                        date = RecurringSchedule.dateOf(rule = rule, month = month),
                                        direction = rule.direction,
                                        amount = rule.amount,
                                        categoryId = rule.categoryId,
                                        memo = rule.memo,
                                    ),
                                recurringRuleId = rule.id,
                                recurringMonth = month,
                            )
                        }
                }
            }
        }

    // Deleted transactions count: a month whose transaction was deleted stays done.
    private fun isRecorded(
        rule: RecurringRule,
        month: String,
    ): Boolean =
        rows.database.transactionsQueries
            .recordedMonthCount(ledgerId = rows.ledgerKey, ruleId = rule.id.toString(), month = month)
            .executeAsOne() > 0L

    private fun ruleRow(id: Uuid): Recurring_rules? =
        queries.liveRecurringRule(ledger_id = rows.ledgerKey, id = id.toString()).executeAsOneOrNull()

    private fun rule(id: Uuid): RecurringRule? = ruleRow(id)?.toDomain()

    // Resuming an ended rule, by clearing its end month or moving it later,
    // skips the months whose date came while it was ended: the first month
    // it may record then is the first after the end whose date is still to
    // come. `null` when it is not resumed or nothing is skipped.
    private fun resumedFrom(
        current: RecurringRule,
        rule: NewRecurringRule,
        today: LocalDate,
    ): YearMonth? {
        val ended = current.endMonth?.takeIf { end -> rule.endMonth == null || rule.endMonth > end } ?: return null
        val firstAfterEnd = ended.plusMonth()
        val firstToCome =
            generateSequence(firstAfterEnd) { it.plusMonth() }.first { month ->
                RecurringSchedule.dateOf(month = month, dayOfMonth = rule.dayOfMonth, adjustment = rule.adjustment) >
                    today
            }
        return firstToCome.takeIf { it > firstAfterEnd }
    }

    private fun requireShape(rule: NewRecurringRule) {
        require(rule.amount >= MIN_AMOUNT) { "金額は1円以上にしてください" }
        require(rule.dayOfMonth == null || rule.dayOfMonth in FIRST_DAY_OF_MONTH..LAST_DAY_OF_MONTH) {
            "日付は1〜31日か月末にしてください"
        }
        // An ended rule that recorded nothing ends the month before its start.
        require(rule.endMonth == null || rule.endMonth >= rule.startMonth.minusMonth()) {
            "終了月は開始月以降にしてください"
        }
        when (rule.direction) {
            Direction.EXPENSE -> requireNotNull(rule.categoryId) { "カテゴリを選んでください" }
            Direction.INCOME -> require(rule.categoryId == null) { "収入には分類を付けません" }
        }
    }
}

package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.BusinessDayAdjustment
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewRecurringRule
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.domain.TransactionQuery
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.time.Instant
import kotlin.uuid.Uuid

private const val RENT_AMOUNT = 80_000L
private const val RENT_AMOUNT_CHANGED = 85_000L
private const val RENT_DAY = 25
private const val SALARY_AMOUNT = 250_000L
private const val MANUAL_AMOUNT = 1_000L
private const val MATERIALISATION_ATTEMPTS = 3

// Noon in Asia/Tokyo on each "today" of the criterion.
private val APRIL_24: Instant = Instant.parse("2026-04-24T12:00:00+09:00")
private val APRIL_27: Instant = Instant.parse("2026-04-27T12:00:00+09:00")
private val MAY_24: Instant = Instant.parse("2026-05-24T12:00:00+09:00")
private val MAY_25: Instant = Instant.parse("2026-05-25T12:00:00+09:00")

private val JANUARY: YearMonth = YearMonth.parse("2026-01")
private val MARCH: YearMonth = YearMonth.parse("2026-03")
private val APRIL: YearMonth = YearMonth.parse("2026-04")
private val MAY: YearMonth = YearMonth.parse("2026-05")

// The months each rule has been recorded for, with the date each was recorded on.
private val RENT_UP_TO_MARCH: List<Pair<YearMonth, LocalDate>> =
    listOf(
        JANUARY to LocalDate.parse("2026-01-26"),
        FIXTURE_FEBRUARY to LocalDate.parse("2026-02-25"),
        MARCH to LocalDate.parse("2026-03-25"),
    )
private val RENT_UP_TO_APRIL: List<Pair<YearMonth, LocalDate>> =
    RENT_UP_TO_MARCH + (APRIL to LocalDate.parse("2026-04-27"))
private val RENT_UP_TO_MAY: List<Pair<YearMonth, LocalDate>> =
    RENT_UP_TO_APRIL + (MAY to LocalDate.parse("2026-05-25"))
private val SALARY_UP_TO_MARCH: List<Pair<YearMonth, LocalDate>> =
    listOf(
        JANUARY to LocalDate.parse("2026-01-30"),
        FIXTURE_FEBRUARY to LocalDate.parse("2026-02-27"),
        MARCH to LocalDate.parse("2026-03-31"),
    )

/**
 * AC-B-206 — Recurring rules are recorded automatically on their date, once.
 *
 * Given a rule of 80,000 yen 住居 on day 25, moved to the next business day,
 * from 2026-01 with no end; a rule of 250,000 yen income on the month's last
 * day, moved to the previous business day, from 2026-01; and a manual expense
 * of 1,000 食費 on 2026-02-25. When materialisation runs three times with
 * today 2026-04-24, then the 住居 rule has exactly one transaction for each of
 * 2026-01, 2026-02 and 2026-03, dated 2026-01-26 (the 25th is a Sunday),
 * 2026-02-25 and 2026-03-25, and none yet for 2026-04; the income rule has
 * one for each of 2026-01, 2026-02 and 2026-03, dated 2026-01-30 (the 31st is
 * a Saturday), 2026-02-27 (the 28th is a Saturday) and 2026-03-31, with no
 * category; each names its rule; and the manual expense is untouched. When
 * today becomes 2026-04-27 and materialisation runs, then the 住居 rule gains
 * exactly one transaction, dated 2026-04-27 (the 25th is a Saturday). When
 * the 住居 rule is changed to 85,000 yen, then the recorded ones stay 80,000
 * and 2026-05's is recorded as 85,000 once its date comes. When the 2026-02
 * 住居 transaction is deleted and materialisation runs again, then it is not
 * recorded again.
 *
 * "Today" is the injected clock read in Asia/Tokyo (noon of the day here);
 * materialisation reads nothing else.
 */
class TestRecurringMaterialisation {
    /**
     * Each month of each rule is recorded once, on its business-day-adjusted
     * date, and a change reaches only later months.
     */
    @Test
    fun recordsEachMonthOnceOnItsDate(): TestResult =
        runTest {
            val clock = ManualClock(current = APRIL_24)
            val scope = kakeiScope(clock = clock)
            val housing = scope.categoryIdNamed(name = "住居")
            val rentRule =
                NewRecurringRule(
                    direction = Direction.EXPENSE,
                    amount = RENT_AMOUNT,
                    categoryId = housing,
                    dayOfMonth = RENT_DAY,
                    startMonth = JANUARY,
                    endMonth = null,
                    adjustment = BusinessDayAdjustment.NEXT_BUSINESS_DAY,
                )
            val rent = scope.createRecurringRule(rule = rentRule)
            val salary =
                scope.createRecurringRule(
                    rule =
                        NewRecurringRule(
                            direction = Direction.INCOME,
                            amount = SALARY_AMOUNT,
                            categoryId = null,
                            dayOfMonth = null,
                            startMonth = JANUARY,
                            adjustment = BusinessDayAdjustment.PREVIOUS_BUSINESS_DAY,
                        ),
                )
            val manual = recordManualExpense(scope = scope)

            repeat(times = MATERIALISATION_ATTEMPTS) { scope.materializeRecurringRules() }

            assertRecordedUpToMarch(scope = scope, rent = rent, salary = salary, housing = housing, manual = manual)

            clock.current = APRIL_27
            scope.materializeRecurringRules()
            assertEquals(
                expected = RENT_UP_TO_APRIL,
                actual = scope.recordedMonths(ruleId = rent.id),
                message = "4月27日 に 住居 の 4月 分が 4月27日 付けで 1 件だけ増えない",
            )
            assertEquals(expected = SALARY_UP_TO_MARCH, actual = scope.recordedMonths(ruleId = salary.id))

            scope.updateRecurringRule(ruleId = rent.id, rule = rentRule.copy(amount = RENT_AMOUNT_CHANGED))
            assertRecordedAs(
                scope = scope,
                ruleId = rent.id,
                direction = Direction.EXPENSE,
                amount = RENT_AMOUNT,
                categoryId = housing,
            )
            assertMayOnItsDate(clock = clock, scope = scope, rentId = rent.id)
            assertDeletedMonthStaysDone(scope = scope, rentId = rent.id)
        }
}

// After the runs on 2026-04-24: each rule once for each of January to March, the manual expense untouched.
internal suspend fun assertRecordedUpToMarch(
    scope: LedgerScope,
    rent: RecurringRule,
    salary: RecurringRule,
    housing: Uuid,
    manual: Transaction,
) {
    assertEquals(
        expected = RENT_UP_TO_MARCH,
        actual = scope.recordedMonths(ruleId = rent.id),
        message = "住居 の定期が 1月26日・2月25日・3月25日 の 1 件ずつでない（4月 はまだ）",
    )
    assertEquals(
        expected = SALARY_UP_TO_MARCH,
        actual = scope.recordedMonths(ruleId = salary.id),
        message = "収入の定期が 1月30日・2月27日・3月31日 の 1 件ずつでない",
    )
    assertRecordedAs(
        scope = scope,
        ruleId = rent.id,
        direction = Direction.EXPENSE,
        amount = RENT_AMOUNT,
        categoryId = housing,
    )
    assertRecordedAs(
        scope = scope,
        ruleId = salary.id,
        direction = Direction.INCOME,
        amount = SALARY_AMOUNT,
        categoryId = null,
    )
    assertEquals(expected = manual, actual = scope.findTransaction(id = manual.id), message = "手で記録した支出が変わった")
    assertEquals(
        expected = RENT_UP_TO_MARCH.size + SALARY_UP_TO_MARCH.size + 1,
        actual = scope.allOfTheYear().size,
        message = "定期の記録と手で記録した支出のほかに取引ができた",
    )
}

// The manual expense of 1,000円 食費 on 2026-02-25.
internal suspend fun recordManualExpense(scope: LedgerScope): Transaction =
    scope.recordTransaction(
        transaction =
            NewTransaction(
                date = LocalDate.parse("2026-02-25"),
                direction = Direction.EXPENSE,
                amount = MANUAL_AMOUNT,
                categoryId = scope.categoryIdNamed(name = "食費"),
            ),
    )

// After the change to 85,000円: nothing for May on the 24th; on the 25th, May's is 85,000円 and the rest stay 80,000円.
internal suspend fun assertMayOnItsDate(
    clock: ManualClock,
    scope: LedgerScope,
    rentId: Uuid,
) {
    clock.current = MAY_24
    scope.materializeRecurringRules()
    assertEquals(
        expected = RENT_UP_TO_APRIL,
        actual = scope.recordedMonths(ruleId = rentId),
        message = "5月25日 より前に 住居 の 5月 分が記録された",
    )

    clock.current = MAY_25
    scope.materializeRecurringRules()
    scope.materializeRecurringRules()
    val rentRecords = scope.recordsOf(ruleId = rentId)
    assertEquals(
        expected = RENT_UP_TO_MAY,
        actual = rentRecords.map { record -> record.recurringMonth to record.date },
        message = "5月25日 に 住居 の 5月 分が 1 件だけ記録されない",
    )
    assertEquals(
        expected = List(size = RENT_UP_TO_APRIL.size) { RENT_AMOUNT } + RENT_AMOUNT_CHANGED,
        actual = rentRecords.map { record -> record.amount },
        message = "記録済みの 住居 が 80,000円 のまま、5月 分が 85,000円 になっていない",
    )
}

// Deleting February's 住居 and materialising again (today 2026-05-25) records February no more.
internal suspend fun assertDeletedMonthStaysDone(
    scope: LedgerScope,
    rentId: Uuid,
) {
    val february = scope.recordsOf(ruleId = rentId).single { record -> record.recurringMonth == FIXTURE_FEBRUARY }
    scope.deleteTransaction(transactionId = february.id)
    repeat(times = MATERIALISATION_ATTEMPTS) { scope.materializeRecurringRules() }
    assertEquals(
        expected = RENT_UP_TO_MAY.filter { (month, _) -> month != FIXTURE_FEBRUARY },
        actual = scope.recordedMonths(ruleId = rentId),
        message = "削除した 住居 の 2月 分が記録し直された",
    )
}

// Every record of the rule [ruleId] is of [direction], [amount] and [categoryId], and names the rule.
internal suspend fun assertRecordedAs(
    scope: LedgerScope,
    ruleId: Uuid,
    direction: Direction,
    amount: Long,
    categoryId: Uuid?,
) {
    val records = scope.recordsOf(ruleId = ruleId)
    assertEquals(
        expected = List(size = records.size) { Triple(direction, amount, categoryId) },
        actual = records.map { record -> Triple(record.direction, record.amount, record.categoryId) },
        message = "定期の記録の向き・金額・分類が定期と違う",
    )
    assertEquals(
        expected = List(size = records.size) { ruleId },
        actual =
            records.map { record ->
                record.recurringRuleId
            },
    )
}

// The live transactions of 2026, in date order.
internal suspend fun LedgerScope.allOfTheYear(): List<Transaction> =
    searchTransactions(
        query = TransactionQuery(from = LocalDate.parse("2026-01-01"), to = LocalDate.parse("2026-12-31")),
    ).sortedBy { found -> found.date }

// The live transactions that name the rule [ruleId], in date order.
internal suspend fun LedgerScope.recordsOf(ruleId: Uuid): List<Transaction> =
    allOfTheYear().filter { found -> found.recurringRuleId == ruleId }

// The month each record of the rule [ruleId] was recorded for, with its date, in date order.
internal suspend fun LedgerScope.recordedMonths(ruleId: Uuid): List<Pair<YearMonth?, LocalDate>> =
    recordsOf(ruleId = ruleId).map { record -> record.recurringMonth to record.date }

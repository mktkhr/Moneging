package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.BusinessDayAdjustment
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewRecurringRule
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.time.Instant
import kotlin.uuid.Uuid

private const val RENT_AMOUNT = 80_000L
private const val RENT_DAY = 25

// Noon in Asia/Tokyo on each "today" of the criterion.
private val FEBRUARY_26: Instant = Instant.parse("2026-02-26T12:00:00+09:00")
private val MARCH_26: Instant = Instant.parse("2026-03-26T12:00:00+09:00")
private val APRIL_10: Instant = Instant.parse("2026-04-10T12:00:00+09:00")
private val APRIL_26: Instant = Instant.parse("2026-04-26T12:00:00+09:00")

private val JANUARY: YearMonth = YearMonth.parse("2026-01")
private val MARCH: YearMonth = YearMonth.parse("2026-03")
private val APRIL: YearMonth = YearMonth.parse("2026-04")

private val JANUARY_AND_FEBRUARY: List<Pair<YearMonth?, LocalDate>> =
    listOf(
        JANUARY to LocalDate.parse("2026-01-25"),
        FIXTURE_FEBRUARY to LocalDate.parse("2026-02-25"),
    )
private val WITH_APRIL: List<Pair<YearMonth?, LocalDate>> =
    JANUARY_AND_FEBRUARY + (APRIL to LocalDate.parse("2026-04-25"))

/**
 * AC-B-211 — A recurring rule is ended, resumed and deleted; recorded ones stay.
 *
 * Given today 2026-02-26 and a 住居 rule of 80,000 yen on day 25, kept on
 * non-business days, from 2026-01, whose 2026-01 and 2026-02 transactions have
 * been recorded. When it is ended, then its end month reads 2026-02, and when
 * today becomes 2026-03-26 and materialisation runs, then nothing is recorded
 * for 2026-03. When, on 2026-04-10, its end month is cleared, and today becomes
 * 2026-04-26 and materialisation runs, then exactly one transaction is recorded
 * for 2026-04, dated 2026-04-25, and 2026-03 still has none. When the rule is
 * deleted, then it is no longer listed, and the transactions of 2026-01,
 * 2026-02 and 2026-04 remain, each still naming it.
 *
 * Ending is `endRecurringRule(ruleId)` and deleting is
 * `deleteRecurringRule(ruleId)` of the ledger scope; resuming is the ordinary
 * update with the end month cleared.
 */
class TestRecurringRuleLifecycle {
    /** Ending stops later months, clearing the end month resumes without back-filling, deleting keeps the records. */
    @Test
    fun endsResumesAndDeletesRule(): TestResult =
        runTest {
            val clock = ManualClock(current = FEBRUARY_26)
            val scope = kakeiScope(clock = clock)
            val housing = scope.categoryIdNamed(name = "住居")
            val newRule =
                NewRecurringRule(
                    direction = Direction.EXPENSE,
                    amount = RENT_AMOUNT,
                    categoryId = housing,
                    dayOfMonth = RENT_DAY,
                    startMonth = JANUARY,
                    endMonth = null,
                    adjustment = BusinessDayAdjustment.KEEP,
                )
            val rule = scope.createRecurringRule(rule = newRule)
            scope.materializeRecurringRules()
            assertEquals(
                expected = JANUARY_AND_FEBRUARY,
                actual = scope.recordedMonths(ruleId = rule.id),
                message = "前提の 1月25日・2月25日 の記録がない",
            )

            val ended = scope.endRecurringRule(ruleId = rule.id)
            assertEquals(expected = FIXTURE_FEBRUARY, actual = ended.endMonth, message = "終了した定期の終了月が 2026-02 でない")

            clock.current = MARCH_26
            scope.materializeRecurringRules()
            assertEquals(
                expected = JANUARY_AND_FEBRUARY,
                actual = scope.recordedMonths(ruleId = rule.id),
                message = "終了した定期の 3月 分が記録された",
            )

            clock.current = APRIL_10
            val resumed = scope.updateRecurringRule(ruleId = rule.id, rule = newRule.copy(endMonth = null))
            assertEquals(expected = null, actual = resumed.endMonth, message = "終了月を消しても再開しない")
            clock.current = APRIL_26
            scope.materializeRecurringRules()
            scope.materializeRecurringRules()
            assertEquals(
                expected = WITH_APRIL,
                actual = scope.recordedMonths(ruleId = rule.id),
                message = "再開した定期が 4月25日 の 1 件だけを記録しない（3月 は記録されない）",
            )
            assertEquals(
                expected = emptyList(),
                actual = scope.recordedMonths(ruleId = rule.id).filter { (month, _) -> month == MARCH },
                message = "終了中の 3月 分が記録された",
            )

            assertDeletingKeepsRecords(scope = scope, ruleId = rule.id, categoryId = housing)
        }

    private suspend fun assertDeletingKeepsRecords(
        scope: LedgerScope,
        ruleId: Uuid,
        categoryId: Uuid,
    ) {
        scope.deleteRecurringRule(ruleId = ruleId)
        assertEquals(expected = emptyList(), actual = scope.recurringRules(), message = "削除した定期がまだ並ぶ")
        assertEquals(
            expected = WITH_APRIL,
            actual = scope.recordedMonths(ruleId = ruleId),
            message = "定期を削除すると記録済みの 1月・2月・4月 の取引が残らない",
        )
        assertRecordedAs(
            scope = scope,
            ruleId = ruleId,
            direction = Direction.EXPENSE,
            amount = RENT_AMOUNT,
            categoryId = categoryId,
        )
    }
}

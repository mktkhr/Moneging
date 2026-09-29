package io.github.mktkhr.moneging.domain

import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

private const val RENT = 80_000L
private const val RENT_DAY = 25

/** When a rule's months fall, and what 次回 names. */
class RecurringScheduleTest {
    /** On 2026-02-26 a rule on the 25th moved to the next weekday is due for February, next on 3月25日（水）. */
    @Test
    fun nextDateIsTheFirstAfterToday() {
        val rent = rule(Direction.EXPENSE, RENT, RENT_DAY)
        val today = LocalDate.parse("2026-02-26")
        assertEquals(expected = listOf(YearMonth.parse("2026-02")), actual = RecurringSchedule.monthsDue(rent, today))
        assertEquals(expected = LocalDate.parse("2026-03-25"), actual = RecurringSchedule.nextDate(rent, today))
    }

    /** A day the month does not have means its last day. */
    @Test
    fun dayBeyondTheMonthIsItsLastDay() {
        assertEquals(
            expected = LocalDate.parse("2026-02-28"),
            actual = RecurringSchedule.dateOf(YearMonth.parse("2026-02"), dayOfMonth = 31, BusinessDayAdjustment.KEEP),
        )
    }

    /** Amount text reads whole yen with separators and full-width digits, and nothing else. */
    @Test
    fun amountTextReadsWholeYen() {
        assertEquals(expected = 1_200L, actual = AmountText.parse(" 1,200 "))
        assertEquals(expected = 1_200L, actual = AmountText.parse("１２００"))
        assertFailsWith<IllegalArgumentException> { AmountText.parse("") }
        assertFailsWith<IllegalArgumentException> { AmountText.parse("-1") }
    }

    /** 2027's holidays: the vernal equinox on 3月21日 (a Sunday) moves its substitute to the 22nd. */
    @Test
    fun substituteAfterSundayEquinox() {
        assertEquals(
            expected = LocalDate.parse("2027-03-23"),
            actual = BusinessCalendar.nextBusinessDay(onOrAfter = LocalDate.parse("2027-03-20")),
        )
    }
}

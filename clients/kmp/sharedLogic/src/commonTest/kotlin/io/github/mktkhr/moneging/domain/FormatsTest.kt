package io.github.mktkhr.moneging.domain

import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.time.Instant
import kotlin.uuid.Uuid

private const val RENT = 80_000L
private const val SALARY = 250_000L
private const val RENT_DAY = 25
private const val NEGATIVE = -2_200L
private const val THOUSANDS = 1_200L

/** How amounts, dates, months and recurring rules are written. */
class FormatsTest {
    /** Amounts are grouped by thousands and end in 円; a negative one starts with −. */
    @Test
    fun writesAmounts() {
        assertEquals(expected = "1,200円", actual = Formats.yen(THOUSANDS))
        assertEquals(expected = "0円", actual = Formats.yen(0L))
        assertEquals(expected = "−2,200円", actual = Formats.yen(NEGATIVE))
    }

    /** Dates, weekdays and months are written in Japanese. */
    @Test
    fun writesDatesAndMonths() {
        val date = LocalDate.parse("2026-02-14")
        assertEquals(expected = "2月14日", actual = Formats.date(date))
        assertEquals(expected = "2月14日（土）", actual = Formats.dateWithWeekday(date))
        assertEquals(expected = "2026年2月", actual = Formats.month(YearMonth.parse("2026-02")))
    }

    /** A rule reads its day, amount and category; a month-end income reads 毎月末日 and 収入. */
    @Test
    fun writesRecurringRules() {
        assertEquals(
            expected = "毎月25日 80,000円 住居",
            actual = Formats.recurringRule(rule(Direction.EXPENSE, RENT, RENT_DAY), categoryName = "住居"),
        )
        assertEquals(
            expected = "毎月末日 250,000円 収入",
            actual = Formats.recurringRule(rule(Direction.INCOME, SALARY, null), categoryName = null),
        )
        assertEquals(expected = "土日祝なら翌平日", actual = Formats.adjustment(BusinessDayAdjustment.NEXT_BUSINESS_DAY))
        assertEquals(expected = null, actual = Formats.adjustment(BusinessDayAdjustment.KEEP))
    }
}

/** A rule of [direction], [amount] and [day] from 2026-02, moved to the next business day. */
internal fun rule(
    direction: Direction,
    amount: Long,
    day: Int?,
): RecurringRule =
    RecurringRule(
        id = Uuid.random(),
        ledgerId = Uuid.random(),
        direction = direction,
        amount = amount,
        categoryId = null,
        dayOfMonth = day,
        startMonth = YearMonth.parse("2026-02"),
        endMonth = null,
        memo = null,
        adjustment = BusinessDayAdjustment.NEXT_BUSINESS_DAY,
        createdAt = Instant.fromEpochMilliseconds(0L),
        updatedAt = Instant.fromEpochMilliseconds(0L),
    )

package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.BusinessCalendar
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

// A Wednesday that is a business day: its own next and previous business day.
private const val BUSINESS_DAY = "2026-02-25"

/**
 * AC-B-209 — Business days follow Japanese public holidays and the year-end
 * break.
 *
 * When the next business day is read for 2026-05-03, then it is 2026-05-07
 * (Constitution Day, Greenery Day, Children's Day and the substitute holiday
 * on the 6th). For 2026-09-19, it is 2026-09-24 (Respect for the Aged Day on
 * the 21st, the autumnal equinox on the 23rd and the citizens' holiday
 * between them). For 2026-12-31, it is 2027-01-04. When the previous business
 * day is read for 2027-01-03, then it is 2026-12-30, and for 2026-03-20 (the
 * vernal equinox), 2026-03-19. 2026-02-25 is its own business day either way.
 *
 * "The next business day for a date" is the first business day on or after
 * it, "the previous" the last on or before it: a business day is its own.
 */
class TestBusinessDays {
    /** The next business day skips Golden Week, the September holidays and the year-end break. */
    @Test
    fun nextBusinessDay() {
        val expected =
            listOf(
                "2026-05-03" to "2026-05-07",
                "2026-09-19" to "2026-09-24",
                "2026-12-31" to "2027-01-04",
                BUSINESS_DAY to BUSINESS_DAY,
            )
        assertEquals(
            expected = expected.map { (_, next) -> LocalDate.parse(next) },
            actual = expected.map { (date, _) -> BusinessCalendar.nextBusinessDay(onOrAfter = LocalDate.parse(date)) },
            message = "翌営業日が 5月7日・9月24日・1月4日・2月25日 にならない",
        )
    }

    /** The previous business day skips the year-end break and the vernal equinox. */
    @Test
    fun previousBusinessDay() {
        val expected =
            listOf(
                "2027-01-03" to "2026-12-30",
                "2026-03-20" to "2026-03-19",
                BUSINESS_DAY to BUSINESS_DAY,
            )
        assertEquals(
            expected = expected.map { (_, previous) -> LocalDate.parse(previous) },
            actual =
                expected.map { (date, _) ->
                    BusinessCalendar.previousBusinessDay(onOrBefore = LocalDate.parse(date))
                },
            message = "前営業日が 12月30日・3月19日・2月25日 にならない",
        )
    }
}

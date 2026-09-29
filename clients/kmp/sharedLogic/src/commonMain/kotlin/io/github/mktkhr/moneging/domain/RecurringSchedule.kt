package io.github.mktkhr.moneging.domain

import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlinx.datetime.minusMonth
import kotlinx.datetime.onDay
import kotlinx.datetime.plusMonth
import kotlinx.datetime.yearMonth

/**
 * When a recurring rule's months fall: a month's date is its day (a day the
 * month does not have, or none, meaning the last day), moved by the rule's
 * business-day adjustment; it stays that month's even when the move puts it
 * in another month.
 */
object RecurringSchedule {
    /** The date the month [month] of a rule on [dayOfMonth] with [adjustment] falls on. */
    fun dateOf(
        month: YearMonth,
        dayOfMonth: Int?,
        adjustment: BusinessDayAdjustment,
    ): LocalDate {
        val day = dayOfMonth?.coerceAtMost(month.numberOfDays) ?: month.numberOfDays
        val date = month.onDay(day)
        return when (adjustment) {
            BusinessDayAdjustment.KEEP -> date
            BusinessDayAdjustment.NEXT_BUSINESS_DAY -> BusinessCalendar.nextBusinessDay(onOrAfter = date)
            BusinessDayAdjustment.PREVIOUS_BUSINESS_DAY -> BusinessCalendar.previousBusinessDay(onOrBefore = date)
        }
    }

    /** The date [rule]'s month [month] falls on. */
    fun dateOf(
        rule: RecurringRule,
        month: YearMonth,
    ): LocalDate = dateOf(month = month, dayOfMonth = rule.dayOfMonth, adjustment = rule.adjustment)

    /** The months of [rule] whose date is on or before [today], in order. */
    fun monthsDue(
        rule: RecurringRule,
        today: LocalDate,
    ): List<YearMonth> {
        // A move reaches a few days at most, so the month after today's is the last that can be due.
        val last = listOfNotNull(rule.endMonth, today.yearMonth.plusMonth()).min()
        return generateSequence(rule.startMonth) { it.plusMonth() }
            .takeWhile { it <= last }
            .filter { dateOf(rule, it) <= today }
            .toList()
    }

    /** The first date of [rule] after [today] (`次回`), or `null` when the rule has ended by then. */
    fun nextDate(
        rule: RecurringRule,
        today: LocalDate,
    ): LocalDate? {
        // A move reaches a few days at most, so the month before today's is the earliest still to come.
        val first = maxOf(a = rule.startMonth, b = today.yearMonth.minusMonth())
        return generateSequence(first) { it.plusMonth() }
            .takeWhile { month -> rule.endMonth == null || month <= rule.endMonth }
            .map { dateOf(rule, it) }
            .firstOrNull { it > today }
    }
}

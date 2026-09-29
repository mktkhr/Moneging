package io.github.mktkhr.moneging.domain

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.DayOfWeek
import kotlinx.datetime.LocalDate
import kotlinx.datetime.Month
import kotlinx.datetime.minus
import kotlinx.datetime.plus

// The equinox formula's constants (valid 1980-2099), scaled by a million so
// the day is computed in integers: day = floor(base + 0.242194 × n) - floor(n / 4),
// n = year - 1980.
private const val EQUINOX_EPOCH_YEAR = 1980
private const val EQUINOX_SCALE = 1_000_000L
private const val VERNAL_EQUINOX_BASE = 20_843_100L
private const val AUTUMNAL_EQUINOX_BASE = 23_248_800L
private const val EQUINOX_DRIFT_PER_YEAR = 242_194L
private const val LEAP_CYCLE_YEARS = 4

// Which occurrence of Monday a Happy-Monday holiday falls on.
private const val SECOND_MONDAY = 2
private const val THIRD_MONDAY = 3
private const val DAYS_IN_WEEK = 7

// The year-end break: 31 December to 3 January.
private const val YEAR_END_DAY = 31
private const val NEW_YEAR_BREAK_LAST_DAY = 3

// Fixed-date holidays of the Public Holiday Act, as ISO month-day (MM-dd).
private val FIXED_HOLIDAYS: Set<String> =
    setOf("01-01", "02-11", "02-23", "04-29", "05-03", "05-04", "05-05", "08-11", "11-03", "11-23")

// Where the month-day starts in an ISO date (yyyy-MM-dd).
private const val ISO_MONTH_DAY_START = 5

// Happy-Monday holidays, as (month, which Monday).
private val HAPPY_MONDAYS: Set<Pair<Month, Int>> =
    setOf(
        Month.JANUARY to SECOND_MONDAY,
        Month.JULY to THIRD_MONDAY,
        Month.SEPTEMBER to THIRD_MONDAY,
        Month.OCTOBER to SECOND_MONDAY,
    )

/**
 * Japanese business days: a weekday that is neither a public holiday nor
 * in the year-end break (31 December to 3 January). Public holidays are
 * computed on the device from the Public Holiday Act: the fixed-date days,
 * the Happy-Monday days, the vernal and autumnal equinoxes, substitute
 * holidays (the next non-holiday after a holiday on a Sunday) and
 * citizens' holidays (a day between two holidays).
 */
object BusinessCalendar {
    /** Whether [date] is a business day. */
    fun isBusinessDay(date: LocalDate): Boolean =
        date.dayOfWeek != DayOfWeek.SATURDAY &&
            date.dayOfWeek != DayOfWeek.SUNDAY &&
            !isYearEndBreak(date) &&
            !isPublicHoliday(date)

    /** The first business day on or after [onOrAfter]. */
    fun nextBusinessDay(onOrAfter: LocalDate): LocalDate {
        var date = onOrAfter
        while (!isBusinessDay(date)) date = date.plus(1, DateTimeUnit.DAY)
        return date
    }

    /** The last business day on or before [onOrBefore]. */
    fun previousBusinessDay(onOrBefore: LocalDate): LocalDate {
        var date = onOrBefore
        while (!isBusinessDay(date)) date = date.minus(1, DateTimeUnit.DAY)
        return date
    }

    /** Whether [date] is a public holiday, substitute and citizens' holidays included. */
    fun isPublicHoliday(date: LocalDate): Boolean =
        isNamedHoliday(date) || isSubstituteHoliday(date) || isCitizensHoliday(date)
}

internal fun isYearEndBreak(date: LocalDate): Boolean =
    when {
        date.month == Month.DECEMBER -> date.day == YEAR_END_DAY
        date.month == Month.JANUARY -> date.day <= NEW_YEAR_BREAK_LAST_DAY
        else -> false
    }

// A holiday the Act names by date or rule (not a substitute or citizens' one).
internal fun isNamedHoliday(date: LocalDate): Boolean =
    date.toString().substring(ISO_MONTH_DAY_START) in FIXED_HOLIDAYS || isHappyMonday(date) || isEquinox(date)

internal fun isHappyMonday(date: LocalDate): Boolean {
    val ordinal = (date.day - 1) / DAYS_IN_WEEK + 1
    return date.dayOfWeek == DayOfWeek.MONDAY && date.month to ordinal in HAPPY_MONDAYS
}

internal fun isEquinox(date: LocalDate): Boolean =
    when {
        date.month == Month.MARCH -> date.day == equinoxDay(date.year, VERNAL_EQUINOX_BASE)
        date.month == Month.SEPTEMBER -> date.day == equinoxDay(date.year, AUTUMNAL_EQUINOX_BASE)
        else -> false
    }

// The first non-holiday after a run of holidays that includes a Sunday.
internal fun isSubstituteHoliday(date: LocalDate): Boolean {
    if (isNamedHoliday(date)) return false
    val holidaysBefore =
        generateSequence(date.minus(1, DateTimeUnit.DAY)) { it.minus(1, DateTimeUnit.DAY) }
            .takeWhile { isNamedHoliday(it) }
    return holidaysBefore.any { it.dayOfWeek == DayOfWeek.SUNDAY }
}

internal fun isCitizensHoliday(date: LocalDate): Boolean =
    !isNamedHoliday(date) &&
        isNamedHoliday(date.minus(1, DateTimeUnit.DAY)) &&
        isNamedHoliday(date.plus(1, DateTimeUnit.DAY))

internal fun equinoxDay(
    year: Int,
    base: Long,
): Int {
    val elapsed = (year - EQUINOX_EPOCH_YEAR).toLong()
    return ((base + EQUINOX_DRIFT_PER_YEAR * elapsed) / EQUINOX_SCALE - elapsed / LEAP_CYCLE_YEARS).toInt()
}

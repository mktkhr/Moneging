package io.github.mktkhr.moneging.domain

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.DayOfWeek
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlinx.datetime.number
import kotlinx.datetime.plus

private const val DIGIT_GROUP = 3
private const val MINUS_SIGN = "−"

/**
 * How the product writes amounts, dates, months and recurring rules
 * (`1,200円`, `2月3日`, `2026年2月`, `毎月25日 80,000円 住居`), the same on
 * every client.
 */
object Formats {
    /** [amount] yen as `1,200円` (a negative one as `−1,200円`). */
    fun yen(amount: Long): String {
        val digits = if (amount < 0) (-amount).toString() else amount.toString()
        val grouped =
            digits
                .reversed()
                .chunked(DIGIT_GROUP)
                .joinToString(separator = ",")
                .reversed()
        return (if (amount < 0) MINUS_SIGN else "") + grouped + "円"
    }

    /** [date] as `2月3日`. */
    fun date(date: LocalDate): String = "${date.month.number}月${date.day}日"

    /** [date] with its weekday, as `2月14日（土）`. */
    fun dateWithWeekday(date: LocalDate): String = "${date(date)}（${weekday(date.dayOfWeek)}）"

    /** [month] as `2026年2月`. */
    fun month(month: YearMonth): String = "${month.year}年${month.month.number}月"

    /** The weekday [day] as one character, `月` to `日`. */
    fun weekday(day: DayOfWeek): String =
        when (day) {
            DayOfWeek.MONDAY -> "月"
            DayOfWeek.TUESDAY -> "火"
            DayOfWeek.WEDNESDAY -> "水"
            DayOfWeek.THURSDAY -> "木"
            DayOfWeek.FRIDAY -> "金"
            DayOfWeek.SATURDAY -> "土"
            DayOfWeek.SUNDAY -> "日"
        }

    /** When a rule falls each month: `毎月25日`, or `毎月末日` for the last day. */
    fun recurringDay(dayOfMonth: Int?): String = if (dayOfMonth == null) "毎月末日" else "毎月${dayOfMonth}日"

    /**
     * A rule as `毎月25日 80,000円 住居`: its day, amount and [categoryName]
     * (`収入` for an income).
     */
    fun recurringRule(
        rule: RecurringRule,
        categoryName: String?,
    ): String {
        val what = if (rule.direction == Direction.INCOME) "収入" else categoryName.orEmpty()
        return "${recurringDay(rule.dayOfMonth)} ${yen(rule.amount)} $what".trimEnd()
    }

    /** The adjustment of a moved rule (`土日祝なら翌平日`), or `null` for one kept on its date. */
    fun adjustment(adjustment: BusinessDayAdjustment): String? =
        when (adjustment) {
            BusinessDayAdjustment.KEEP -> null
            BusinessDayAdjustment.NEXT_BUSINESS_DAY -> "土日祝なら翌平日"
            BusinessDayAdjustment.PREVIOUS_BUSINESS_DAY -> "土日祝なら前の平日"
        }
}

/** [Formats] from ISO text, for clients that hold dates and months as text. */
object IsoFormats {
    /** The ISO date [iso] (`2026-02-15`) as `2月15日`, with its weekday (`2月15日（日）`) when [withWeekday]. */
    fun date(
        iso: String,
        withWeekday: Boolean,
    ): String {
        val date = LocalDate.parse(iso)
        return if (withWeekday) Formats.dateWithWeekday(date) else Formats.date(date)
    }

    /** The ISO month [iso] (`2026-02`) as `2026年2月`. */
    fun month(iso: String): String = Formats.month(YearMonth.parse(iso))

    /** The ISO months from [before] months before the ISO month [center] to [after] months after it. */
    fun monthsAround(
        center: String,
        before: Int,
        after: Int,
    ): List<String> {
        val middle = YearMonth.parse(center)
        return (-before..after).map { offset -> middle.plus(offset, DateTimeUnit.MONTH).toString() }
    }
}

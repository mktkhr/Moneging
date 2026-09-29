package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.Formats
import io.github.mktkhr.moneging.domain.Shares
import kotlinx.datetime.DayOfWeek
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlinx.datetime.isoDayNumber
import kotlinx.datetime.number

// How the calendar and the report show the month in view (PRODUCT.md §5,
// Reports and calendar), the same on every client: the texts are composed
// here, the platforms only draw them.

private const val NMD = "NMD"
private const val YEN = "円"
private const val PERCENT = "%"
private const val DAYS_IN_WEEK = 7

// The weekdays of a calendar's columns: weeks start on Sunday.
private val WEEK: List<DayOfWeek> =
    listOf(
        DayOfWeek.SUNDAY,
        DayOfWeek.MONDAY,
        DayOfWeek.TUESDAY,
        DayOfWeek.WEDNESDAY,
        DayOfWeek.THURSDAY,
        DayOfWeek.FRIDAY,
        DayOfWeek.SATURDAY,
    )

/** One day of the calendar. */
data class CalendarDay(
    /** The day, ISO (`2026-02-03`). */
    val date: String,
    /** Its day of the month (`3`). */
    val dayNumber: String,
    /** Its spending in full, without the unit (`4,000`), or `null` when it has none. */
    val amountText: String?,
    /** Whether it shows the NMD badge: a past day with no spending, not before the ledger was created. */
    val isNoMoneyDay: Boolean,
    /** Whether it is today. */
    val isToday: Boolean,
    /** Whether it is after today. */
    val isFuture: Boolean,
    /** Whether it is a Sunday. */
    val isSunday: Boolean,
    /** Whether it is a Saturday. */
    val isSaturday: Boolean,
    /** What a screen reader says: `2月3日 4,000円`, `2月4日 NMD`, or the date alone (`2月15日`). */
    val accessibilityLabel: String,
)

/** The month in view as the calendar draws it. */
data class CalendarMonth(
    /** The month (`2026年2月`). */
    val title: String,
    /** The month's spending (`18,250円`). */
    val expenseText: String,
    /** The weekdays of its columns, Sunday first (`日` to `土`). */
    val weekdayNames: List<String>,
    /** The empty cells before its first day, 0 to 6. */
    val leadingBlankDays: Int,
    /** Every day of the month, in order. */
    val days: List<CalendarDay>,
)

/** One category of the month's share. */
data class ShareRow(
    /** The category's `Category.id`, as text. */
    val categoryId: String,
    /** Its name. */
    val name: String,
    /** Its spending (`3,000円`). */
    val amountText: String,
    /** Its whole percentage (`50%`); the month's add up to 100%. */
    val percentText: String,
    /** Where its arc of the ring starts, 0 to 1, clockwise from the top. */
    val ringStart: Double,
    /** Where its arc of the ring ends, 0 to 1. */
    val ringEnd: Double,
    /** The default category it shows the colour of (`Category.defaultIndex`), or `null`. */
    val iconIndex: Int?,
    /** What a screen reader says: `食費 3,000円 50%`. */
    val accessibilityLabel: String,
)

/** One month of the trend. */
data class TrendRow(
    /** The month, ISO (`2025-04`). */
    val month: String,
    /** Its number, under its bar (`4`). */
    val monthNumber: String,
    /** The month (`2025年4月`). */
    val title: String,
    /** Its spending (`1,000円`). */
    val amountText: String,
    /** Its bar's height as a fraction of the tallest, 0 to 1. */
    val barFraction: Double,
    /** Whether it is the month in view. */
    val isMonthInView: Boolean,
    /** What a screen reader says: `2025年4月 1,000円`. */
    val accessibilityLabel: String,
)

/** The month in view as the report shows it. */
data class MonthReport(
    /** The share's title (`2月の内訳`). */
    val shareTitle: String,
    /** The month's spending, at the ring's centre (`18,250円`). */
    val expenseText: String,
    /** Each category with spending, largest first. */
    val shares: List<ShareRow>,
    /** The months the trend covers (`2025年3月〜2026年2月`). */
    val trendRange: String,
    /** The twelve months ending with the month in view, oldest first. */
    val trend: List<TrendRow>,
)

/**
 * The month read as the calendar draws it, on [todayIso]; the NMD badge is
 * never shown before [ledgerCreatedOnIso]. `null` before a month is read.
 */
fun LedgerUiState.calendarMonth(
    todayIso: String,
    ledgerCreatedOnIso: String?,
): CalendarMonth? {
    val month = month ?: return null
    val today = LocalDate.parse(todayIso)
    val createdOn = ledgerCreatedOnIso?.let { LocalDate.parse(it) }
    return CalendarMonth(
        title = Formats.month(month),
        expenseText = Formats.yen(totals.expense),
        weekdayNames = WEEK.map { Formats.weekday(it) },
        leadingBlankDays = month.firstDay.dayOfWeek.isoDayNumber % DAYS_IN_WEEK,
        days =
            dailyTotals.map { total ->
                val date = total.date
                val isNoMoneyDay = total.amount == 0L && date < today && (createdOn == null || date >= createdOn)
                val amountText = Formats.yen(total.amount).removeSuffix(YEN).takeIf { total.amount > 0L }
                CalendarDay(
                    date = date.toString(),
                    dayNumber = date.day.toString(),
                    amountText = amountText,
                    isNoMoneyDay = isNoMoneyDay,
                    isToday = date == today,
                    isFuture = date > today,
                    isSunday = date.dayOfWeek == DayOfWeek.SUNDAY,
                    isSaturday = date.dayOfWeek == DayOfWeek.SATURDAY,
                    accessibilityLabel =
                        when {
                            amountText != null -> "${Formats.date(date)} ${Formats.yen(total.amount)}"
                            isNoMoneyDay -> "${Formats.date(date)} $NMD"
                            else -> Formats.date(date)
                        },
                )
            },
    )
}

/** The month read as the report shows it; `null` before a month is read. */
fun LedgerUiState.monthReport(): MonthReport? {
    val month = month
    val report = report
    if (month == null || report == null) return null
    val percentages = Shares.percentages(report.categories.map { it.amount })
    var ringStart = 0.0
    val shares =
        report.categories.mapIndexed { index, total ->
            val category = categories.firstOrNull { it.id == total.categoryId }
            val name = category?.name.orEmpty()
            val amountText = Formats.yen(total.amount)
            val percentText = "${percentages[index]}$PERCENT"
            val start = ringStart
            ringStart += total.amount.toDouble() / report.expenseTotal.toDouble()
            ShareRow(
                categoryId = total.categoryId.toString(),
                name = name,
                amountText = amountText,
                percentText = percentText,
                ringStart = start,
                ringEnd = ringStart,
                iconIndex = category?.defaultIndex,
                accessibilityLabel = "$name $amountText $percentText",
            )
        }
    val tallest = trend.maxOfOrNull { it.amount } ?: 0L
    return MonthReport(
        shareTitle = "${month.month.number}月の内訳",
        expenseText = Formats.yen(report.expenseTotal),
        shares = shares,
        trendRange = trendRange(from = trend.firstOrNull()?.month ?: month, to = month),
        trend =
            trend.map { total ->
                val title = Formats.month(total.month)
                val amountText = Formats.yen(total.amount)
                TrendRow(
                    month = total.month.toString(),
                    monthNumber =
                        total.month.month.number
                            .toString(),
                    title = title,
                    amountText = amountText,
                    barFraction = if (tallest > 0L) total.amount.toDouble() / tallest.toDouble() else 0.0,
                    isMonthInView = total.month == month,
                    accessibilityLabel = "$title $amountText",
                )
            },
    )
}

// The months from [from] to [to] as `2025年3月〜2026年2月`.
private fun trendRange(
    from: YearMonth,
    to: YearMonth,
): String = "${Formats.month(from)}〜${Formats.month(to)}"

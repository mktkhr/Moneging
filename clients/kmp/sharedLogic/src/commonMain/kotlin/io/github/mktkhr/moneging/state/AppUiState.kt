package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.Formats
import io.github.mktkhr.moneging.domain.Ledger
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlinx.datetime.number
import kotlinx.datetime.yearMonth

/**
 * The single state shared by every tab. [AppState] publishes this as a
 * single `StateFlow`; the UI never derives its own copy.
 */
data class AppUiState(
    /** The month in view: the month of [today] until the user changes it. */
    val selectedMonth: YearMonth,
    /** Today, by the injected clock in Asia/Tokyo. */
    val today: LocalDate,
    /** Whether the ledgers and the tour's progress have been read from the device. */
    val isLoaded: Boolean,
    /** Every ledger the user can change to, in creation order. */
    val ledgers: List<Ledger>,
    /** The identifier (`Ledger.id`) of the ledger in view, or `null` before the first ledger exists. */
    val selectedLedgerId: String?,
    /** The tour step shown, or `null` when the tour is not shown. */
    val tour: TourState?,
    /** The name typed in the tour's ledger step. */
    val ledgerNameDraft: String,
    /** A failed operation to tell the user about, or `null`. */
    val errorMessage: String?,
) {
    /** The year of [selectedMonth]. */
    val selectedYear: Int
        get() = selectedMonth.year

    /** The month number of [selectedMonth], 1-12. */
    val selectedMonthNumber: Int
        get() = selectedMonth.month.number

    /** The month in view as the header names it: `2月`, with its year when it is not today's (`2025年2月`). */
    val selectedMonthTitle: String
        get() =
            if (selectedMonth.year == today.year) "${selectedMonthNumber}月" else Formats.month(selectedMonth)

    /** [today], ISO (`2026-02-15`). */
    val todayIso: String
        get() = today.toString()

    /** The month of [today], ISO (`2026-02`). */
    val todayMonthIso: String
        get() = today.yearMonth.toString()

    /** The ledger in view, or `null` before the first ledger exists. */
    val selectedLedger: Ledger?
        get() = ledgers.firstOrNull { it.id.toString() == selectedLedgerId }

    /**
     * The name the header shows for the ledger in view: while the tour's
     * ledger step is shown, the name being typed.
     */
    val ledgerTitle: String
        get() = if (tour?.step == TourStep.LEDGER) ledgerNameDraft else selectedLedger?.name.orEmpty()
}

/**
 * This state on [today]: when the day has changed, the month in view moves
 * with it if it was the old today's month.
 */
fun AppUiState.withToday(today: LocalDate): AppUiState {
    if (today == this.today) return this
    val isFollowingToday = selectedMonth == this.today.yearMonth
    return copy(today = today, selectedMonth = if (isFollowingToday) today.yearMonth else selectedMonth)
}

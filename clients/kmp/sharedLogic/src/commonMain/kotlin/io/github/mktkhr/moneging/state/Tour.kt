package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.PreferenceKeys
import io.github.mktkhr.moneging.data.Preferences

/**
 * The steps of the guided tour over the app, in the order they are shown.
 * A later stage adds a step by adding an entry here (and its callout on
 * each platform).
 */
enum class TourStep {
    /** Names and creates the first ledger; cannot be skipped. */
    LEDGER,

    /** The floating record button. */
    RECORD,

    /** The tab bar: calendar, report and budget. */
    TABS,
    ;

    /** The step after this one, or `null` for the last. */
    val next: TourStep?
        get() = entries.getOrNull(ordinal + 1)
}

/** The tour step shown, and where it stands among the steps of this run of the tour. */
data class TourState(
    /** The step shown. */
    val step: TourStep,
    /** Its position among [count] steps, from 0. */
    val position: Int,
    /** How many steps this run of the tour has (a replay has no ledger step). */
    val count: Int,
    /** Whether this is a replay from the settings, whose progress is not kept. */
    val isReplay: Boolean,
) {
    /** Factories for [TourState]. */
    companion object {
        /** [step] of the tour run from its first step, or, for a replay, from the step after the ledger step. */
        fun forStep(
            step: TourStep,
            isReplay: Boolean,
        ): TourState {
            val first = if (isReplay) TourStep.RECORD.ordinal else 0
            return TourState(
                step = step,
                position = step.ordinal - first,
                count = TourStep.entries.size - first,
                isReplay = isReplay,
            )
        }
    }
}

/**
 * The tour's progress, kept in [preferences] so that a launch resumes the
 * tour at the first step not yet done. A replay's progress is not kept.
 */
internal class TourProgress(
    private val preferences: Preferences,
) {
    /**
     * The step a launch shows: the ledger step on a device with no ledger
     * (starting the tour over), else the first step not yet done, or none
     * once the tour is finished.
     */
    fun onLaunch(hasLedger: Boolean): TourState? {
        if (!hasLedger) {
            preferences.setString(key = PreferenceKeys.TOUR_NEXT_STEP, value = null)
            return TourState.forStep(step = TourStep.LEDGER, isReplay = false)
        }
        val saved = preferences.string(PreferenceKeys.TOUR_NEXT_STEP)
        val isUnfinished = saved != null && saved != PreferenceKeys.TOUR_FINISHED
        // A ledger exists, so the ledger step is done even if its end was not kept.
        val step = TourStep.entries.firstOrNull { it.name == saved && it != TourStep.LEDGER } ?: TourStep.RECORD
        return if (isUnfinished) TourState.forStep(step = step, isReplay = false) else null
    }

    /** The step after [tour], or `null` when [tour] was the last. */
    fun advance(tour: TourState): TourState? {
        val next = tour.step.next
        if (!tour.isReplay) {
            preferences.setString(
                key = PreferenceKeys.TOUR_NEXT_STEP,
                value = next?.name ?: PreferenceKeys.TOUR_FINISHED,
            )
        }
        return next?.let { TourState.forStep(step = it, isReplay = tour.isReplay) }
    }

    /** Ends the tour; the ledger step cannot be skipped, so it stays. */
    fun skip(tour: TourState): TourState? {
        if (tour.step == TourStep.LEDGER) return tour
        preferences.setString(key = PreferenceKeys.TOUR_NEXT_STEP, value = PreferenceKeys.TOUR_FINISHED)
        return null
    }

    /** The replay from the settings: from the step after the ledger step. */
    fun replay(): TourState = TourState.forStep(step = TourStep.RECORD, isReplay = true)
}

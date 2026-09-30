package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.scan.ScanJob

/**
 * The scans in flight in every ledger, as the progress outside the app
 * shows them (PRODUCT.md §3, Scan job): whatever ledger is in view, it
 * lasts while any scan of any ledger is queued or running.
 */
data class ScanProgress(
    /** Scans queued or running, in every ledger. */
    val inFlight: Int,
    /** Drafts waiting, in every ledger. */
    val waiting: Int,
    /** Scans of the current run (since none was in flight) that have finished. */
    val finishedInRun: Int,
    /** Scans the current run has. */
    val totalInRun: Int,
    /** The names of the ledgers with a scan in flight, in creation order. */
    val ledgerNames: List<String>,
) {
    /** Whether any scan is in flight: the progress is shown outside the app. */
    val isInFlight: Boolean
        get() = inFlight > 0

    /** Whom the scans are of: the ledger's name, or `2つの家計簿` for several. */
    val ledgerLabel: String
        get() = ledgerNames.singleOrNull() ?: "${ledgerNames.size}つの家計簿"

    /** Factories for [ScanProgress]. */
    companion object {
        /** Nothing in flight. */
        val NONE: ScanProgress =
            ScanProgress(inFlight = 0, waiting = 0, finishedInRun = 0, totalInRun = 0, ledgerNames = emptyList())
    }
}

/** The scans in flight in every ledger of this store. */
internal suspend fun LocalStore.scanProgress(): ScanProgress {
    var waiting = 0
    val jobs = mutableListOf<ScanJob>()
    val names = mutableListOf<String>()
    ledgers().forEach { each ->
        val scope = ledger(each.id)
        val ledgerJobs = scope.scanJobs()
        jobs += ledgerJobs
        waiting += scope.waitingDrafts().size
        if (ledgerJobs.any { it.state.isInFlight }) names += each.name
    }
    val runStart = jobs.filter { it.state.isInFlight }.minOfOrNull { it.createdAt }
    val run = if (runStart == null) emptyList() else jobs.filter { it.createdAt >= runStart }
    return ScanProgress(
        inFlight = jobs.count { it.state.isInFlight },
        waiting = waiting,
        finishedInRun = run.count { !it.state.isInFlight },
        totalInRun = run.size,
        ledgerNames = names,
    )
}

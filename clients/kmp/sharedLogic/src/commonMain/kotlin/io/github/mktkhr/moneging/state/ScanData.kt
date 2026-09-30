package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Formats
import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.ScanJob
import io.github.mktkhr.moneging.scan.ScanState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.uuid.Uuid

private const val READ_FAILED = "読み取りの状況を読み込めませんでした"

/** A draft waiting to be confirmed, as the list of scans shows it. */
data class WaitingDraftRow(
    /** The draft's id, as text. */
    val id: String,
    /** The photo it was read from, as text. */
    val photoId: String,
    /** Its store name (`セブン-イレブン`), or `店名なし`. */
    val store: String,
    /** Its date (`2月14日`). */
    val dateText: String,
    /** Its total (`1,180円`). */
    val totalText: String,
    /** What a screen reader says: `セブン-イレブン 1,180円、2月14日`. */
    val accessibilityLabel: String,
)

/** A scan being read, or one that failed. */
data class ScanJobRow(
    /** The job's id, as text. */
    val id: String,
    /** The photo it reads, as text. */
    val photoId: String,
    /** Why it failed, or `null` while it is in flight. */
    val failureReason: String?,
)

/** The scans of the ledger in view (PRODUCT.md §5, Receipt reading). */
data class ScanUiState(
    /** The ledger they are of (`Ledger.id` as text), or `null`. */
    val ledgerId: String?,
    /** The drafts waiting, newest first. */
    val waiting: List<WaitingDraftRow>,
    /** The scans queued or running, oldest first. */
    val inFlight: List<ScanJobRow>,
    /** The failed scans still to be dealt with: not read again, their photo not recorded. */
    val failed: List<ScanJobRow>,
    /** How many scans of the current run (since none was in flight) have finished. */
    val finishedInRun: Int,
    /** How many scans the current run has. */
    val totalInRun: Int,
    /** Why reading failed, or `null`. */
    val loadErrorMessage: String?,
) {
    /** How many scans are queued or running. */
    val inFlightCount: Int
        get() = inFlight.size

    /** How many drafts wait. */
    val waitingCount: Int
        get() = waiting.size

    /** Whether any scan is queued or running: its progress is shown outside the app. */
    val isInFlight: Boolean
        get() = inFlight.isNotEmpty()

    /** `読み取り中 1件`. */
    val inFlightText: String
        get() = "読み取り中 ${inFlightCount}件"

    /** `確認待ち 2件`. */
    val waitingText: String
        get() = "確認待ち ${waitingCount}件"

    /** `読み取れなかったもの 1件`. */
    val failedText: String
        get() = "読み取れなかったもの ${failed.size}件"

    /**
     * What home shows below the ledger's name while any scan is in flight or
     * any draft waits (`読み取り中 1件・確認待ち 2件`), else `null`.
     */
    val statusText: String?
        get() =
            listOfNotNull(
                inFlightText.takeIf { inFlightCount > 0 },
                waitingText.takeIf { waitingCount > 0 },
            ).joinToString(separator = "・").ifEmpty { null }

    /** Whether the list of scans has anything to show. */
    val hasAny: Boolean
        get() = waiting.isNotEmpty() || inFlight.isNotEmpty() || failed.isNotEmpty()

    /** Factories for [ScanUiState]. */
    companion object {
        /** Nothing read yet. */
        val EMPTY: ScanUiState =
            ScanUiState(
                ledgerId = null,
                waiting = emptyList(),
                inFlight = emptyList(),
                failed = emptyList(),
                finishedInRun = 0,
                totalInRun = 0,
                loadErrorMessage = null,
            )
    }
}

/** The notice that [count] photos were accepted for reading: `2枚の読み取りを受け付けました`. */
fun scanAcceptedNotice(count: Int): String = "${count}枚の読み取りを受け付けました"

/**
 * App-lifetime holder of [ScanUiState]: the scans of the ledger in view,
 * read again whenever the ledger changes and whenever a scan, a draft, a
 * photo or a transaction changes. Jobs and drafts are read from the
 * database, so reopening the app finds them again.
 */
class ScanData internal constructor(
    private val store: LocalStore,
    appState: AppState,
    dispatcher: CoroutineDispatcher = Dispatchers.Default,
) {
    private val coroutineScope = CoroutineScope(SupervisorJob() + dispatcher)
    private val mutableUiState = MutableStateFlow(ScanUiState.EMPTY)

    /** The scans of the ledger in view. */
    val uiState: StateFlow<ScanUiState> = mutableUiState.asStateFlow()

    init {
        coroutineScope.launch { observe(appState) }
    }

    /** Cancels this holder's coroutine scope; see [AppState.close]. */
    fun close() {
        coroutineScope.cancel()
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private suspend fun observe(appState: AppState) {
        val ledgerInView = appState.uiState.map { it.selectedLedgerId }.distinctUntilChanged()
        combine(ledgerInView, store.observeScanChanges().conflate()) { ledgerId, _ -> ledgerId }
            .collectLatest { ledgerId -> read(ledgerId) }
    }

    private suspend fun read(ledgerId: String?) {
        if (ledgerId == null) {
            mutableUiState.value = ScanUiState.EMPTY
            return
        }
        try {
            mutableUiState.value = store.ledger(Uuid.parse(ledgerId)).scanUiState()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (expected: IllegalStateException) {
            mutableUiState.update { it.copy(loadErrorMessage = expected.message ?: READ_FAILED) }
        }
    }
}

/** The scans of this ledger as its screens show them. */
internal suspend fun LedgerScope.scanUiState(): ScanUiState {
    val jobs = scanJobs()
    val linked = linkedPhotoIds()
    val inFlight = jobs.filter { it.state.isInFlight }
    // The newest job of each photo: a photo read again shows only its new scan.
    val latest = jobs.groupBy { it.photoId }.mapValues { (_, photoJobs) -> photoJobs.last().id }
    val failed = jobs.filter { it.state == ScanState.FAILED && latest[it.photoId] == it.id && it.photoId !in linked }
    val runStart = inFlight.minOfOrNull { it.createdAt }
    val run = if (runStart == null) emptyList() else jobs.filter { it.createdAt >= runStart }
    return ScanUiState(
        ledgerId = ledgerId.toString(),
        waiting = waitingDrafts().map { it.toRow() },
        inFlight = inFlight.map { it.toRow() },
        failed = failed.map { it.toRow() },
        finishedInRun = run.count { !it.state.isInFlight },
        totalInRun = run.size,
        loadErrorMessage = null,
    )
}

private fun ScanJob.toRow(): ScanJobRow =
    ScanJobRow(id = id.toString(), photoId = photoId.toString(), failureReason = failureReason)

private fun Draft.toRow(): WaitingDraftRow {
    val storeName = store.value.trim().ifEmpty { "店名なし" }
    val totalText = Formats.yen(total.value)
    val dateText = Formats.date(date.value)
    return WaitingDraftRow(
        id = id.toString(),
        photoId = photoId.toString(),
        store = storeName,
        dateText = dateText,
        totalText = totalText,
        accessibilityLabel = "$storeName $totalText、$dateText",
    )
}

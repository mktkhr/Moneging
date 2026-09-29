package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.MonthTotals
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.Transaction
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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

private const val READ_FAILED = "記録を読み込めませんでした"
private const val MATERIALIZE_FAILED = "毎月の定期を記録できませんでした"

/** The records of the ledger in view that its screens show, for the month in view. */
data class LedgerUiState(
    /** The ledger they are of (`Ledger.id` as text), or `null` before one exists. */
    val ledgerId: String?,
    /** The month [transactions] and [totals] are of. */
    val month: YearMonth?,
    /** Whether they have been read for [ledgerId] and [month]. */
    val isLoaded: Boolean,
    /** The month's live transactions, newest first. */
    val transactions: List<Transaction>,
    /** The month's totals. */
    val totals: MonthTotals,
    /** The ledger's categories, archived ones included, in the ledger's order. */
    val categories: List<Category>,
    /** The ledger's live recurring rules, in creation order. */
    val recurringRules: List<RecurringRule>,
    /** Why reading failed, or `null`. */
    val loadErrorMessage: String?,
) {
    /** The ledger's categories that take new transactions. */
    val activeCategories: List<Category>
        get() = categories.filter { !it.isArchived }

    /** Factories for [LedgerUiState]. */
    companion object {
        /** Nothing read yet. */
        val EMPTY: LedgerUiState =
            LedgerUiState(
                ledgerId = null,
                month = null,
                isLoaded = false,
                transactions = emptyList(),
                totals = MonthTotals(expense = 0L, income = 0L),
                categories = emptyList(),
                recurringRules = emptyList(),
                loadErrorMessage = null,
            )
    }
}

/** The category [id] (`Category.id` as text) of [this], or `null`. */
fun LedgerUiState.category(id: String?): Category? =
    id?.let { wanted -> categories.firstOrNull { it.id.toString() == wanted } }

/**
 * App-lifetime holder of [LedgerUiState]: the records of the ledger in view
 * ([AppState]), read again whenever the ledger or the month in view changes
 * and whenever the database changes (docs/handbook/architecture.md, rule 4).
 *
 * It also records the recurring rules whose date has come (PRODUCT.md §3):
 * on launch, when the app returns to the foreground ([onForeground]) and
 * when the day changes ([onTimePassed]), all by the injected clock.
 */
class LedgerData internal constructor(
    private val store: LocalStore,
    private val appState: AppState,
    dispatcher: CoroutineDispatcher = Dispatchers.Default,
) {
    private val coroutineScope = CoroutineScope(SupervisorJob() + dispatcher)
    private val materializing = Mutex()
    private val mutableUiState = MutableStateFlow(LedgerUiState.EMPTY)

    /** The records of the ledger in view. */
    val uiState: StateFlow<LedgerUiState> = mutableUiState.asStateFlow()

    init {
        coroutineScope.launch {
            appState.uiState.first { it.isLoaded }
            materializeReportingFailure()
        }
        coroutineScope.launch { observe() }
    }

    /** On returning to the foreground: reads today again and records the rules whose date has come. */
    fun onForeground() {
        appState.onIntent(AppIntent.RefreshToday)
        coroutineScope.launch { materializeReportingFailure() }
    }

    /** As time passes: when the day has changed, moves today and records the rules whose date has come. */
    fun onTimePassed() {
        val before = appState.uiState.value.today
        appState.onIntent(AppIntent.RefreshToday)
        if (appState.uiState.value.today != before) {
            coroutineScope.launch { materializeReportingFailure() }
        }
    }

    /** Records, in every ledger, each month of each recurring rule whose date has come and is not recorded yet. */
    @Throws(Exception::class)
    suspend fun materializeRecurringRules() {
        materializing.withLock {
            store.ledgers().forEach { ledger -> store.ledger(ledger.id).materializeRecurringRules() }
        }
    }

    /** Cancels this holder's coroutine scope; see [AppState.close]. */
    fun close() {
        coroutineScope.cancel()
    }

    private suspend fun materializeReportingFailure() {
        try {
            materializeRecurringRules()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (expected: IllegalStateException) {
            mutableUiState.update { it.copy(loadErrorMessage = expected.message ?: MATERIALIZE_FAILED) }
        }
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private suspend fun observe() {
        val inView =
            appState.uiState
                .map { it.selectedLedgerId to it.selectedMonth }
                .distinctUntilChanged()
        combine(inView, store.observeRecordChanges().conflate()) { key, _ -> key }
            .collectLatest { (ledgerId, month) -> read(ledgerId = ledgerId, month = month) }
    }

    private suspend fun read(
        ledgerId: String?,
        month: YearMonth,
    ) {
        if (ledgerId == null) {
            mutableUiState.value = LedgerUiState.EMPTY.copy(month = month, isLoaded = true)
            return
        }
        val scope = store.ledger(Uuid.parse(ledgerId))
        try {
            mutableUiState.value =
                LedgerUiState(
                    ledgerId = ledgerId,
                    month = month,
                    isLoaded = true,
                    transactions = scope.transactions(month),
                    totals = scope.monthTotals(month),
                    categories = scope.categories(),
                    recurringRules = scope.recurringRules(),
                    loadErrorMessage = null,
                )
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (expected: IllegalStateException) {
            mutableUiState.update { it.copy(isLoaded = true, loadErrorMessage = expected.message ?: READ_FAILED) }
        }
    }
}

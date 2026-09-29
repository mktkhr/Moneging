package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.data.PreferenceKeys
import io.github.mktkhr.moneging.data.Preferences
import io.github.mktkhr.moneging.domain.Ledger
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.uuid.Uuid

private const val FIRST_MONTH = 1
private const val LAST_MONTH = 12

private const val DEFAULT_LEDGER_NAME = "家計"

/**
 * App-lifetime state holder exposing the app-wide [AppUiState] as a single
 * [StateFlow]. Both clients observe the same instance: Android via Compose
 * (`collectAsStateWithLifecycle`), iOS via SKIE's `AsyncSequence` behind an
 * `@Observable` adapter. Neither client keeps its own copy of the state; a
 * change made on one tab is visible on every other tab.
 *
 * It observes the ledgers in [store], keeps the ledger in view and the
 * tour's progress in [preferences] (so the app reopens on the ledger last in
 * view and resumes an unfinished tour), and runs the tour: shown from its
 * first step whenever the device holds no ledger.
 *
 * A plain class, not an `androidx.lifecycle.ViewModel`: this instance is
 * resolved once from the Koin singleton graph and lives for the app's
 * entire process lifetime, so it has no lifecycle owner to call
 * `ViewModel.onCleared()`. It owns an explicit coroutine scope instead, and
 * [close] cancels that scope for the rare caller (tests) that needs to
 * release it deterministically. See `docs/handbook/architecture.md`.
 */
class AppState internal constructor(
    private val store: LocalStore,
    private val preferences: Preferences,
    dispatcher: CoroutineDispatcher = Dispatchers.Default,
) {
    // Owns the observation of the store; cancelled by close().
    private val coroutineScope = CoroutineScope(SupervisorJob() + dispatcher)
    private val tourProgress = TourProgress(preferences)

    private val mutableUiState =
        MutableStateFlow(
            AppUiState(
                selectedMonth = PLACEHOLDER_MONTH,
                isLoaded = false,
                ledgers = emptyList(),
                selectedLedgerId = null,
                tour = null,
                ledgerNameDraft = DEFAULT_LEDGER_NAME,
                errorMessage = null,
            ),
        )

    /** The single state stream every screen observes. */
    val uiState: StateFlow<AppUiState> = mutableUiState.asStateFlow()

    init {
        coroutineScope.launch {
            store.observeLedgers().collect { ledgers -> applyLedgers(ledgers) }
        }
    }

    /** Applies [intent], producing the next [AppUiState] at once. */
    fun onIntent(intent: AppIntent) {
        when (intent) {
            is AppIntent.SelectMonth -> {
                if (intent.month in FIRST_MONTH..LAST_MONTH) {
                    mutableUiState.update { it.copy(selectedMonth = intent.month) }
                }
            }

            is AppIntent.SelectLedger -> {
                selectLedger(intent.ledgerId)
            }

            is AppIntent.ChangeLedgerNameDraft -> {
                mutableUiState.update { it.copy(ledgerNameDraft = intent.name) }
            }

            AppIntent.AdvanceTour -> {
                // The ledger step moves on only by creating the ledger.
                changeTour { tour -> if (tour.step == TourStep.LEDGER) tour else tourProgress.advance(tour) }
            }

            AppIntent.SkipTour -> {
                changeTour { tour -> tourProgress.skip(tour) }
            }

            AppIntent.ReplayTour -> {
                if (mutableUiState.value.selectedLedger != null) {
                    mutableUiState.update { it.copy(tour = tourProgress.replay()) }
                }
            }

            AppIntent.DismissError -> {
                mutableUiState.update { it.copy(errorMessage = null) }
            }
        }
    }

    /**
     * Creates the first ledger with the name typed in the tour's ledger
     * step, shows it and moves the tour to its next step. Returns whether it
     * was created; a refused name is shown as [AppUiState.errorMessage].
     */
    @Throws(Exception::class)
    suspend fun createFirstLedger(): Boolean {
        val state = mutableUiState.value
        val tour = state.tour?.takeIf { it.step == TourStep.LEDGER }
        val ledger = tour?.let { createOrReport(state.ledgerNameDraft) }
        if (tour != null && ledger != null) {
            reloadLedgers()
            selectLedger(ledger.id.toString())
            mutableUiState.update { it.copy(tour = tourProgress.advance(tour)) }
        }
        return ledger != null
    }

    /**
     * Adds a ledger named [name] and shows it. Returns whether it was added;
     * a refused name is shown as [AppUiState.errorMessage].
     */
    @Throws(Exception::class)
    suspend fun addLedger(name: String): Boolean {
        val ledger = createOrReport(name) ?: return false
        reloadLedgers()
        selectLedger(ledger.id.toString())
        return true
    }

    /**
     * Renames the ledger [ledgerId] to [name]; the ledger in view stays as
     * it is. Returns whether it was renamed; a refusal is shown as
     * [AppUiState.errorMessage].
     */
    @Throws(Exception::class)
    suspend fun renameLedger(
        ledgerId: String,
        name: String,
    ): Boolean {
        try {
            store.renameLedger(id = Uuid.parse(ledgerId), name = name)
        } catch (refused: IllegalArgumentException) {
            mutableUiState.update { it.copy(errorMessage = refused.message) }
            return false
        }
        reloadLedgers()
        return true
    }

    /** Cancels this store's coroutine scope. Not called during normal app life; see the class doc comment. */
    fun close() {
        coroutineScope.cancel()
    }

    private fun selectLedger(ledgerId: String) {
        val isKnownLedger = mutableUiState.value.ledgers.any { it.id.toString() == ledgerId }
        if (!isKnownLedger) return
        preferences.setString(key = PreferenceKeys.LEDGER_IN_VIEW, value = ledgerId)
        mutableUiState.update { it.copy(selectedLedgerId = ledgerId) }
    }

    private fun changeTour(change: (TourState) -> TourState?) {
        val tour = mutableUiState.value.tour ?: return
        mutableUiState.update { it.copy(tour = change(tour)) }
    }

    private fun applyLedgers(ledgers: List<Ledger>) {
        if (mutableUiState.value.isLoaded) {
            // A ledger is never deleted, so after the first read only the list changes.
            mutableUiState.update { it.copy(ledgers = ledgers) }
            return
        }
        val saved = preferences.string(PreferenceKeys.LEDGER_IN_VIEW)
        val selected = ledgers.firstOrNull { it.id.toString() == saved } ?: ledgers.firstOrNull()
        val tour = tourProgress.onLaunch(hasLedger = ledgers.isNotEmpty())
        mutableUiState.update { current ->
            current.copy(
                isLoaded = true,
                ledgers = ledgers,
                selectedLedgerId = selected?.run { id.toString() },
                tour = tour,
            )
        }
    }

    private suspend fun createOrReport(name: String): Ledger? =
        try {
            store.createLedger(name)
        } catch (refused: IllegalArgumentException) {
            mutableUiState.update { it.copy(errorMessage = refused.message) }
            null
        }

    // Reads the ledgers again after a write, so the state holds the change
    // when the write returns (the observation catches up on its own).
    private suspend fun reloadLedgers() {
        val ledgers = store.ledgers()
        mutableUiState.update { it.copy(ledgers = ledgers) }
    }

    private companion object {
        const val PLACEHOLDER_MONTH = 9
    }
}

package io.github.mktkhr.moneging.state

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

private const val FIRST_MONTH = 1
private const val LAST_MONTH = 12

/**
 * App-lifetime state holder exposing the app-wide [AppUiState] as a single
 * [StateFlow]. Both clients observe the same instance: Android via Compose
 * (`collectAsStateWithLifecycle`), iOS via SKIE's `AsyncSequence` behind an
 * `@Observable` adapter. Neither client keeps its own copy of the state; a
 * change made through [onIntent] on one tab is visible on every other tab.
 *
 * A plain class, not an `androidx.lifecycle.ViewModel`: this instance is
 * resolved once from the Koin singleton graph and lives for the app's
 * entire process lifetime, so it has no lifecycle owner to call
 * `ViewModel.onCleared()` and would never actually be cleared - registering
 * it as a `ViewModel` misrepresented its lifetime. It owns an explicit
 * coroutine scope instead, for whichever future work needs structured
 * concurrency (e.g. persistence), and [close] cancels that scope for the
 * rare caller (tests, a future app-teardown path) that needs to release it
 * deterministically.
 *
 * Per-screen state (future work) is a different lifetime: those will be
 * `androidx.lifecycle.ViewModel`s with a real owner (a `NavigationStack`
 * destination), unlike this app-wide store. See
 * `docs/handbook/architecture.md`.
 */
class AppState(
    dispatcher: CoroutineDispatcher = Dispatchers.Default,
) {
    // Owns any coroutine work this store starts; cancelled by close().
    private val coroutineScope = CoroutineScope(SupervisorJob() + dispatcher)

    private val mutableUiState =
        MutableStateFlow(
            AppUiState(
                selectedMonth = PLACEHOLDER_MONTH,
                ledgers = PLACEHOLDER_LEDGERS,
                selectedLedgerId = PLACEHOLDER_LEDGERS.first().id,
            ),
        )

    /** The single state stream every screen observes. */
    val uiState: StateFlow<AppUiState> = mutableUiState.asStateFlow()

    /** Applies [intent], producing the next [AppUiState]. */
    fun onIntent(intent: AppIntent) {
        when (intent) {
            is AppIntent.SelectMonth -> {
                if (intent.month < FIRST_MONTH || intent.month > LAST_MONTH) return
                mutableUiState.update { it.copy(selectedMonth = intent.month) }
            }

            is AppIntent.SelectLedger -> {
                val isKnownLedger = mutableUiState.value.ledgers.any { it.id == intent.ledgerId }
                if (!isKnownLedger) return
                mutableUiState.update { it.copy(selectedLedgerId = intent.ledgerId) }
            }
        }
    }

    /** Cancels this store's coroutine scope. Not called during normal app life; see the class doc comment. */
    fun close() {
        coroutineScope.cancel()
    }

    private companion object {
        const val PLACEHOLDER_MONTH = 9
        val PLACEHOLDER_LEDGERS =
            listOf(
                Ledger(id = "primary", name = "家計"),
                Ledger(id = "secondary", name = "サブ家計簿"),
            )
    }
}

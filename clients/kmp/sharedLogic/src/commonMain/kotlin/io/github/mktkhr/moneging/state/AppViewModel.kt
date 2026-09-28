package io.github.mktkhr.moneging.state

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Shared ViewModel exposing the app-wide [AppUiState] as a single
 * [StateFlow]. Both clients observe the same instance: Android via Compose
 * (`collectAsStateWithLifecycle`), iOS via SKIE's `AsyncSequence` behind an
 * `@Observable` adapter. Neither client keeps its own copy of the state; a
 * change made through [onIntent] on one tab is visible on every other tab.
 */
class AppViewModel : ViewModel() {
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
                mutableUiState.update { it.copy(selectedMonth = intent.month) }
            }

            is AppIntent.SelectLedger -> {
                mutableUiState.update { it.copy(selectedLedgerId = intent.ledgerId) }
            }
        }
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

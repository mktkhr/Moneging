package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.InMemoryPreferences
import io.github.mktkhr.moneging.data.LocalStore
import kotlinx.coroutines.flow.first
import kotlin.time.Clock
import kotlin.time.Instant

// A fixed clock: nothing in the state tests depends on time.
private object FixedClock : Clock {
    override fun now(): Instant = Instant.parse("2026-02-15T03:00:00Z")
}

/**
 * A device's data (an in-memory store and preferences) and launches of the
 * app over it: each [launch] is a new [AppState] over the same data, as
 * after a relaunch.
 */
internal class TestDevice {
    /** The device's database. */
    val store: LocalStore = LocalStore.inMemory(clock = FixedClock, deviceId = "test-device")

    private val preferences = InMemoryPreferences()
    private val launched = mutableListOf<AppState>()

    /** Launches the app and waits until it has read the device's data. */
    suspend fun launch(): AppState {
        val state = AppState(store = store, preferences = preferences, clock = FixedClock)
        launched += state
        state.uiState.first { it.isLoaded }
        return state
    }

    /** Stops every launched app state. */
    fun close() {
        launched.forEach { it.close() }
    }
}

/** The app's current state. */
internal val AppState.ui: AppUiState
    get() = uiState.value

/** The tour step the app shows, or `null`. */
internal val AppState.shownStep: TourStep?
    get() = ui.tour?.step

/** The names of the ledgers the app offers, in order. */
internal val AppState.ledgerNames: List<String>
    get() = ui.ledgers.map { it.name }

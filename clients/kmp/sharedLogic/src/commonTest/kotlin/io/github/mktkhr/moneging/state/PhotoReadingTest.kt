package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.InMemoryPreferences
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.scan.ReadingModule
import io.github.mktkhr.moneging.scan.ReadingModuleInstaller
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.time.Clock
import kotlin.time.Instant

private object PhotoReadingClock : Clock {
    override fun now(): Instant = Instant.parse("2026-02-15T03:00:00Z")
}

/**
 * Reading from photos is off until enabled, the choice is kept on the
 * device, and enabling it asks for the device's modules then, once.
 */
class PhotoReadingTest {
    private val store = LocalStore.inMemory(clock = PhotoReadingClock, deviceId = "test-device")
    private val preferences = InMemoryPreferences()

    /** Enabling asks the installer for the modules once; the choice survives a relaunch. */
    @Test
    fun enablingAsksForTheModulesOnce(): TestResult =
        runTest {
            val requests = mutableListOf<List<ReadingModule>>()
            val installer = ReadingModuleInstaller { requests += it }
            val modules = listOf(ReadingModule.DOCUMENT_SCANNER, ReadingModule.TEXT_RECOGNITION)
            val state = launch(modules = modules, installer = installer)
            assertFalse(state.uiState.value.isPhotoReadingEnabled)

            state.onIntent(AppIntent.SetPhotoReading(isEnabled = true))
            state.onIntent(AppIntent.SetPhotoReading(isEnabled = true))

            assertEquals(expected = listOf(modules), actual = requests)
            state.close()
            val relaunched = launch(modules = modules, installer = installer)
            assertTrue(relaunched.uiState.value.isPhotoReadingEnabled)
            relaunched.close()
        }

    /** A device that needs no module (iOS) asks for nothing. */
    @Test
    fun noModulesAskForNothing(): TestResult =
        runTest {
            val requests = mutableListOf<List<ReadingModule>>()
            val state = launch(modules = emptyList(), installer = { requests += it })

            state.onIntent(AppIntent.SetPhotoReading(isEnabled = true))

            assertTrue(state.uiState.value.isPhotoReadingEnabled)
            assertTrue(requests.isEmpty())
            state.close()
        }

    private fun launch(
        modules: List<ReadingModule>,
        installer: ReadingModuleInstaller,
    ): AppState =
        AppState(
            store = store,
            preferences = preferences,
            clock = PhotoReadingClock,
            readingModules = modules,
            moduleInstaller = installer,
        )
}

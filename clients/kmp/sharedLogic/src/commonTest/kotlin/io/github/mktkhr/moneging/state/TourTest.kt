package io.github.mktkhr.moneging.state

import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Verifies the onboarding tour [AppState] runs: shown from its first step
 * on a device with no ledger, the ledger step creating the first ledger,
 * resumed where it stopped, ended by skipping or finishing, and replayed
 * without its ledger step.
 */
class TourTest {
    private val device = TestDevice()

    /** Stops the app states the test launched. */
    @AfterTest
    fun tearDown() {
        device.close()
    }

    /** A device with no ledger opens on the ledger step, the header reading the name as it is typed. */
    @Test
    fun emptyDeviceShowsLedgerStep(): TestResult =
        runTest {
            val state = device.launch()

            assertEquals(expected = TourStep.LEDGER, actual = state.shownStep)
            assertEquals(expected = "家計", actual = state.ui.ledgerTitle)

            state.onIntent(AppIntent.ChangeLedgerNameDraft(name = "我が家"))

            assertEquals(expected = "我が家", actual = state.ui.ledgerTitle)
            assertEquals(expected = emptyList(), actual = device.store.ledgers(), message = "入力しただけで家計簿ができた")
        }

    /** The ledger step creates the ledger (trimmed), shows it and moves on; it cannot be skipped. */
    @Test
    fun ledgerStepCreatesLedger(): TestResult =
        runTest {
            val state = device.launch()
            state.onIntent(AppIntent.SkipTour)
            state.onIntent(AppIntent.AdvanceTour)
            assertEquals(expected = TourStep.LEDGER, actual = state.shownStep, message = "家計簿の手順を飛ばせた")

            state.onIntent(AppIntent.ChangeLedgerNameDraft(name = " 我が家 "))
            assertTrue(state.createFirstLedger())

            assertEquals(expected = listOf("我が家"), actual = state.ledgerNames)
            assertEquals(expected = "我が家", actual = state.ui.ledgerTitle)
            assertEquals(expected = TourStep.RECORD, actual = state.shownStep)
        }

    /** A refused name creates nothing, keeps the ledger step and says why. */
    @Test
    fun refusedFirstNameIsReported(): TestResult =
        runTest {
            val state = device.launch()
            state.onIntent(AppIntent.ChangeLedgerNameDraft(name = "   "))

            assertFalse(state.createFirstLedger())

            assertEquals(expected = emptyList(), actual = device.store.ledgers())
            assertEquals(expected = TourStep.LEDGER, actual = state.shownStep)
            assertTrue(
                state.ui.errorMessage
                    .orEmpty()
                    .isNotEmpty(),
                "拒否の理由が示されない",
            )
        }

    /** A relaunch before the record step is done resumes there; skipping ends the tour for good. */
    @Test
    fun resumesThenEndsWhenSkipped(): TestResult =
        runTest {
            device.launch().createFirstLedger()

            val resumed = device.launch()
            assertEquals(expected = TourStep.RECORD, actual = resumed.shownStep)
            assertEquals(expected = "家計", actual = resumed.ui.ledgerTitle)

            resumed.onIntent(AppIntent.SkipTour)
            assertNull(resumed.shownStep)
            assertNull(device.launch().shownStep, "スキップ後の再起動でツアーが表示された")
        }

    /** Every step after the ledger step is shown in order, and the last one ends the tour. */
    @Test
    fun finishesAfterItsLastStep(): TestResult =
        runTest {
            val state = device.launch()
            state.createFirstLedger()
            val shown = mutableListOf<TourStep>()
            while (true) {
                shown += state.shownStep ?: break
                state.onIntent(AppIntent.AdvanceTour)
            }

            assertEquals(expected = TourStep.entries.drop(1), actual = shown)
            assertNull(device.launch().shownStep, "最後まで進めた後の再起動でツアーが表示された")
        }

    /** A replay starts at the step after the ledger step, creates no ledger, and is not resumed. */
    @Test
    fun replaySkipsTheLedgerStep(): TestResult =
        runTest {
            val state = device.launch()
            state.createFirstLedger()
            state.onIntent(AppIntent.SkipTour)

            state.onIntent(AppIntent.ReplayTour)
            val tour = state.ui.tour
            state.onIntent(AppIntent.AdvanceTour)

            assertEquals(expected = TourStep.RECORD, actual = tour?.step)
            assertEquals(expected = 0, actual = tour?.position)
            assertEquals(expected = TourStep.entries.size - 1, actual = tour?.count)
            assertEquals(expected = listOf("家計"), actual = device.store.ledgers().map { it.name })
            assertNull(device.launch().shownStep, "見直し途中の再起動でツアーが表示された")
        }
}

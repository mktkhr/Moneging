package io.github.mktkhr.moneging.scan

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first

/**
 * When a scan job may move on to its next state. The product moves at once
 * ([Immediate]); a UI test moves every unfinished job one state on per step
 * ([Stepped]), so it can see each state.
 */
sealed interface ScanPacer {
    /** Suspends until the job may move on from the state it is in. */
    suspend fun awaitMove()

    /** Every job moves on as soon as it can. */
    data object Immediate : ScanPacer {
        override suspend fun awaitMove() {
            // Nothing to wait for.
        }
    }

    /** Every job waits for [step]; each step moves every waiting job one state on. */
    class Stepped : ScanPacer {
        private val steps = MutableStateFlow(0L)

        override suspend fun awaitMove() {
            val seen = steps.value
            steps.first { it > seen }
        }

        /** Moves every waiting job one state on. */
        fun step() {
            steps.value += 1
        }
    }
}

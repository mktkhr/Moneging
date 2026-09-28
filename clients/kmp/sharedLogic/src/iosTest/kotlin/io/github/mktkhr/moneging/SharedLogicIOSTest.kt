package io.github.mktkhr.moneging

import kotlin.test.Test
import kotlin.test.assertEquals

private const val EXPECTED_SUM = 3

/**
 * Smoke test for the `sharedLogic` module's iOS test source set.
 */
class SharedLogicIOSTest {
    /**
     * Verifies the test runner itself is wired up correctly.
     */
    @Test
    fun example() {
        assertEquals(expected = EXPECTED_SUM, actual = 1 + 2)
    }
}

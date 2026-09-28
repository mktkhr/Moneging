package io.github.mktkhr.moneging

import kotlin.test.Test
import kotlin.test.assertEquals

private const val EXPECTED_SUM = 3

/**
 * Smoke test for the `sharedLogic` module's common test source set.
 */
class SharedLogicCommonTest {
    /**
     * Verifies the test runner itself is wired up correctly.
     */
    @Test
    fun example() {
        assertEquals(EXPECTED_SUM, 1 + 2)
    }
}

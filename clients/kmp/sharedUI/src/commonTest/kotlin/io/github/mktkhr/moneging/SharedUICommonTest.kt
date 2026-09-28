package io.github.mktkhr.moneging

import kotlin.test.Test
import kotlin.test.assertEquals

private const val EXPECTED_SUM = 3

/**
 * Smoke test for the `sharedUI` module's common test source set.
 */
class SharedUICommonTest {
    /**
     * Verifies the test runner itself is wired up correctly.
     */
    @Test
    fun example() {
        assertEquals(expected = EXPECTED_SUM, actual = 1 + 2)
    }
}

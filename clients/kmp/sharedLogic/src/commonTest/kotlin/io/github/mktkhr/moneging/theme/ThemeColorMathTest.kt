package io.github.mktkhr.moneging.theme

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

private const val TERRACOTTA_HEX = "#B4472E"

/**
 * Verifies `mixTowardWhite` rounds exactly like JavaScript's `Math.round`
 * (which takamai's own `color.ts` runs on) rather than `kotlin.math.round`
 * (ties round to even; `Math.round` always rounds a `.5` up) - the bug
 * `docs/handbook/architecture.md` describes fixing by using
 * `floor(x + 0.5)`.
 */
class ThemeColorMathTest {
    /**
     * `0.5/255` makes every channel's mixed value land on an exact `.5`
     * boundary (`0 + 255 * (0.5/255) == 0.5`): `kotlin.math.round` ties to
     * even and would keep `0`, but `Math.round`/this fix rounds up to `1`.
     */
    @Test
    fun mixTowardWhiteMatchesJsRound() {
        val amountLandingExactlyOnHalf = 0.5 / 255

        assertEquals(expected = "#010101", actual = mixTowardWhite("#000000", amountLandingExactlyOnHalf))
    }

    /** No mixing (amount 0) leaves the colour unchanged. */
    @Test
    fun noMixLeavesColorUnchanged() {
        assertEquals(expected = TERRACOTTA_HEX, actual = mixTowardWhite(TERRACOTTA_HEX, 0.0))
    }

    /** Full mixing (amount 1) produces white. */
    @Test
    fun fullMixProducesWhite() {
        assertEquals(expected = "#FFFFFF", actual = mixTowardWhite(TERRACOTTA_HEX, 1.0))
    }

    /** `"none"` (a [CardStyle.Border] style's shadow token) has no parse. */
    @Test
    fun noneParsesToNull() {
        assertNull(parseCssBoxShadow("none"))
    }

    /** A well-formed single-layer `box-shadow` parses into its geometry and colour. */
    @Test
    fun parsesGeometryAndColor() {
        val parsed = parseCssBoxShadow("0 8px 22px rgba(120,80,40,0.09)")
        val expected =
            ParsedBoxShadow(offsetX = 0.0, offsetY = 8.0, blurRadius = 22.0, colorHex = "#78502817")

        assertEquals(expected = expected, actual = parsed)
    }
}

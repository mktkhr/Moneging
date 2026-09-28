package io.github.mktkhr.moneging.theme

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Verifies the theme token data and derivation match takamai's reference
 * values exactly (`docs/handbook/architecture.md` change that added this
 * module ports `takamai/frontend/src/shared/theme` verbatim).
 */
class ResolvedThemeTest {
    /** A user who never chose has Soft/テラコッタ (takamai backend's `DefaultAppearance`). */
    @Test
    fun defaultsMatchDefaultAppearance() {
        assertEquals(expected = ThemeStyle.Soft, actual = defaultStyle)
        assertEquals(expected = ThemeColor.Terracotta, actual = defaultColor)
    }

    /** In light mode, the accent is the chosen colour unchanged (`accentMixTowardWhite[Light] == 0`). */
    @Test
    fun lightAccentIsTheColorItself() {
        val resolved = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Light)

        assertEquals(expected = "#B4472E", actual = resolved.accent)
    }

    /** In dark mode, the accent is mixed toward white by `accentMixTowardWhite[Dark]`. */
    @Test
    fun darkAccentIsMixedTowardWhite() {
        val resolved = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Dark)
        val expectedMix = accentMixTowardWhite.getValue(ThemeScheme.Dark)

        assertEquals(expected = mixTowardWhite("#B4472E", expectedMix), actual = resolved.accent)
    }

    /** Light-mode tint has no alpha suffix; dark-mode tint gets `TINT_DARK_ALPHA` appended. */
    @Test
    fun tintAlphaOnlyAppliesInDarkMode() {
        val hexLength = 7
        val hexWithAlphaLength = 9
        val light = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Light)
        val dark = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Dark)

        assertEquals(expected = hexLength, actual = light.accentTint.length)
        assertEquals(expected = hexWithAlphaLength, actual = dark.accentTint.length)
        assertEquals(expected = TINT_DARK_ALPHA, actual = dark.accentTint.takeLast(TINT_DARK_ALPHA.length))
    }

    /** Every style/colour/scheme combination resolves without throwing (exercises the full lookup table). */
    @Test
    fun everyCombinationResolves() {
        for (style in ThemeStyle.entries) {
            for (color in ThemeColor.entries) {
                for (scheme in ThemeScheme.entries) {
                    resolveTheme(style, color, scheme)
                }
            }
        }
    }
}

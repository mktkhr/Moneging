package io.github.mktkhr.moneging.theme

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Verifies the theme token data and derivation match takamai's reference
 * values exactly (`docs/handbook/architecture.md` change that added this
 * module ports `takamai/frontend/src/shared/theme` verbatim).
 *
 * The expected hex values below are not computed by calling this module's
 * own `mixTowardWhite`/`parseCssBoxShadow` (that would just restate the
 * implementation); they are hand-computed from takamai's
 * `frontend/src/shared/theme/color.ts` formula (`channel + (255 - channel)
 * * amount`, `Math.round`-ed per channel) applied to takamai
 * `tokens.ts`'s own literal values (`THEME_COLORS.テラコッタ = "#B4472E"`,
 * `STYLES.Soft.light/dark.shadow`), read 2026-09-28, and independently
 * cross-checked with a standalone Node.js `Math.round` script (not this
 * module) run against the same formula. Soft/テラコッタ dark accent:
 * R 0xB4=180 -> round(180+(255-180)*0.45)=214=0xD6; G 0x47=71 ->
 * round(71+(255-71)*0.45)=154=0x9A; B 0x2E=46 ->
 * round(46+(255-46)*0.45)=140=0x8C -> #D69A8C.
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

    /**
     * In dark mode, the accent is テラコッタ (`#B4472E`) mixed 45% toward
     * white. Expected value hand-computed from takamai's formula, not this
     * module's own `mixTowardWhite` - see the class doc comment.
     */
    @Test
    fun darkAccentIsMixedTowardWhite() {
        val resolved = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Dark)

        assertEquals(expected = "#D69A8C", actual = resolved.accent)
    }

    /**
     * Light-mode tint: テラコッタ mixed 88% toward white, no alpha suffix.
     * R 0xB4=180 -> round(180+75*0.88)=246=0xF6; G 0x47=71 ->
     * round(71+184*0.88)=233=0xE9; B 0x2E=46 -> round(46+209*0.88)=230=0xE6.
     */
    @Test
    fun lightTintMatchesHandComputed() {
        val resolved = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Light)

        assertEquals(expected = "#F6E9E6", actual = resolved.accentTint)
    }

    /**
     * Dark-mode tint: テラコッタ mixed 12% toward white, `TINT_DARK_ALPHA`
     * ("44") appended. R 0xB4=180 -> round(180+75*0.12)=189=0xBD; G 0x47=71
     * -> round(71+184*0.12)=93=0x5D; B 0x2E=46 -> round(46+209*0.12)=71=0x47.
     */
    @Test
    fun darkTintMatchesHandComputed() {
        val resolved = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Dark)

        assertEquals(expected = "#BD5D4744", actual = resolved.accentTint)
    }

    /**
     * Soft light's shadow token (`"0 8px 22px rgba(120,80,40,0.09)"`)
     * parses to an 8pt/22pt-blur shadow; alpha 0.09 * 255 = 22.95, rounded
     * to 23 = 0x17.
     */
    @Test
    fun lightShadowMatchesHandComputed() {
        val resolved = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Light)

        assertEquals(expected = "#78502817", actual = resolved.shadowColor)
        assertEquals(expected = 8.0, actual = resolved.shadowOffsetY)
        assertEquals(expected = 22.0, actual = resolved.shadowBlurRadius)
    }

    /**
     * Soft dark's shadow token (`"0 8px 22px rgba(0,0,0,0.35)"`); alpha
     * 0.35 * 255 = 89.25, rounded to 89 = 0x59.
     */
    @Test
    fun darkShadowMatchesHandComputed() {
        val resolved = resolveTheme(ThemeStyle.Soft, ThemeColor.Terracotta, ThemeScheme.Dark)

        assertEquals(expected = "#00000059", actual = resolved.shadowColor)
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

    /**
     * A style with a flat/bordered card ([CardStyle.Border]) has no shadow
     * token (`"none"`); its shadow parses to transparent, zero geometry.
     */
    @Test
    fun borderStyleHasNoShadow() {
        val resolved = resolveTheme(ThemeStyle.Minimal, ThemeColor.Sumi, ThemeScheme.Light)

        assertEquals(expected = "#00000000", actual = resolved.shadowColor)
        assertEquals(expected = 0.0, actual = resolved.shadowOffsetY)
        assertEquals(expected = 0.0, actual = resolved.shadowBlurRadius)
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

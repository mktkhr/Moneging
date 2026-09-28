package io.github.mktkhr.moneging.theme

// The design's raw tokens, typed as data: five styles, six shared theme
// colours, and the fixed rules for how a colour becomes an accent, a tint
// and a "glass" surface in each colour scheme.
//
// Ported verbatim (same field names, same values) from takamai's reference
// theme - `takamai/frontend/src/shared/theme/tokens.ts`, read 2026-09-28 -
// so Android can reuse these values later; iOS maps this data to a
// SwiftUI `Theme` (`clients/kmp/iosApp/iosApp/Theme.swift`). Pure data: no
// platform colour type, so this module stays platform-independent.

private const val STYLE_SURFACE_COLOR_WHITE = "#FFFFFF"
private const val STYLE_CARD_SHADOW_NONE = "none"
private const val FONT_STACK_ZEN_MARU_GOTHIC = "'Zen Maru Gothic', 'Hiragino Maru Gothic ProN', sans-serif"
private const val FONT_STACK_ZEN_KAKU_GOTHIC_NEW = "'Zen Kaku Gothic New', 'Hiragino Sans', sans-serif"

/** One of the five independent look-and-feel presets (takamai `STYLE_NAMES`, in PRODUCT.md's order). */
enum class ThemeStyle {
    /** やさしい・あたたかい. */
    Soft,

    /** すっきり・ミニマル. */
    Minimal,

    /** 落ち着いた・大人っぽい. */
    Calm,

    /** 元気・カラフル. */
    Bright,

    /** かわいい. */
    Cute,
}

/** One of the six theme colours shared across every style (takamai `COLOR_NAMES`). */
enum class ThemeColor(
    /** The Japanese name PRODUCT.md and takamai's UI show for this colour. */
    val japaneseName: String,
    /** The colour's own hex value (takamai `THEME_COLORS`/`COLOR_HEX`). */
    val hex: String,
) {
    /** テラコッタ: the default colour ([defaultColor]). */
    Terracotta("テラコッタ", "#B4472E"),

    /** ローズ. */
    Rose("ローズ", "#B83E6A"),

    /** ラベンダー. */
    Lavender("ラベンダー", "#6B4FA0"),

    /** ソーダ. */
    Soda("ソーダ", "#2F6690"),

    /** セージ. */
    Sage("セージ", "#3F7A5A"),

    /** 墨. */
    Sumi("墨", "#2B2B28"),
}

/** A colour scheme: light or dark (takamai's MUI `"light" | "dark"`). */
enum class ThemeScheme {
    /** The light colour scheme. */
    Light,

    /** The dark colour scheme. */
    Dark,
}

/** "shadow": a floating card. "border": a flat, outlined one (takamai `StyleTokens.card`). */
enum class CardStyle {
    /** A floating card, lifted with a drop shadow. */
    Shadow,

    /** A flat card, outlined with a border instead of a shadow. */
    Border,
}

/**
 * Whether the home tab's transaction list sits inside a card or lies flat
 * with only a top divider (takamai `StyleTokens.list`; see that field's own
 * doc comment in tokens.ts for why this needs to be separate from
 * [CardStyle]).
 */
enum class ListStyle {
    /** The list sits inside a card ([CardStyle], `"shadow"` or `"border"`). */
    Card,

    /** The list lies flat, only a top divider marking it - Minimal's own choice. */
    Flat,
}

/**
 * A style's own palette for one colour scheme (takamai `StyleSchemeTokens`),
 * independent of the chosen accent colour.
 */
data class StyleSchemeTokens(
    /** Screen background. */
    val bg: String,
    /** A card/row's own surface, distinct from [bg]. */
    val surface: String,
    /** Primary text. */
    val text: String,
    /** Secondary/muted text. */
    val muted: String,
    /** Hairline dividers and card borders. */
    val line: String,
    /** A progress track's own background (e.g. a budget bar). */
    val track: String,
    /** The colour used for a positive (income) amount. */
    val income: String,
    /** This scheme's own CSS `box-shadow` value, or [STYLE_CARD_SHADOW_NONE]. */
    val shadow: String,
)

/** Everything one style decides, in both colour schemes (takamai `StyleTokens`). */
data class StyleTokens(
    /** The style's own Japanese title, as PRODUCT.md and takamai's UI show it. */
    val title: String,
    /** The [ThemeColor] this style defaults to when no colour has been chosen. */
    val defaultAccent: ThemeColor,
    /** The CSS font stack for body text and "amount" numbers. */
    val bodyFont: String,
    /** The CSS font stack for headings. */
    val headFont: String,
    /** The font weight "amount" numbers (amounts of money) render at. */
    val numWeight: Int,
    /** The style's base corner radius, in points. */
    val radius: Int,
    /** A button's own corner radius, in points. */
    val btnRadius: Int,
    /** A chip's own corner radius, in points. */
    val chipRadius: Int,
    /** Whether this style's cards float (a shadow) or lie flat (a border). */
    val card: CardStyle,
    /** Whether this style's home-tab transaction list sits in a card or lies flat. */
    val list: ListStyle,
    /** This style's palette in the light colour scheme. */
    val light: StyleSchemeTokens,
    /** This style's palette in the dark colour scheme. */
    val dark: StyleSchemeTokens,
)

/** `STYLES`: each of the five styles' own tokens, in both colour schemes, values copied verbatim from tokens.ts. */
val themeStyles: Map<ThemeStyle, StyleTokens> =
    mapOf(
        ThemeStyle.Soft to
            StyleTokens(
                title = "やさしい・あたたかい",
                defaultAccent = ThemeColor.Terracotta,
                bodyFont = FONT_STACK_ZEN_MARU_GOTHIC,
                headFont = FONT_STACK_ZEN_MARU_GOTHIC,
                numWeight = 700,
                radius = 22,
                btnRadius = 999,
                chipRadius = 999,
                card = CardStyle.Shadow,
                list = ListStyle.Card,
                light =
                    StyleSchemeTokens(
                        bg = "#FBF6EF",
                        surface = STYLE_SURFACE_COLOR_WHITE,
                        text = "#3A2E28",
                        muted = "#6F5F55",
                        line = "#EFE4D8",
                        track = "#F3E9DE",
                        income = "#2E7D5B",
                        shadow = "0 8px 22px rgba(120,80,40,0.09)",
                    ),
                dark =
                    StyleSchemeTokens(
                        bg = "#211B17",
                        surface = "#2D2520",
                        text = "#F5ECE3",
                        muted = "#C4B3A6",
                        line = "#3E342D",
                        track = "#3A302A",
                        income = "#86D5AE",
                        shadow = "0 8px 22px rgba(0,0,0,0.35)",
                    ),
            ),
        ThemeStyle.Minimal to
            StyleTokens(
                title = "すっきり・ミニマル",
                defaultAccent = ThemeColor.Sumi,
                bodyFont = FONT_STACK_ZEN_KAKU_GOTHIC_NEW,
                headFont = FONT_STACK_ZEN_KAKU_GOTHIC_NEW,
                numWeight = 500,
                radius = 10,
                btnRadius = 10,
                chipRadius = 6,
                card = CardStyle.Border,
                list = ListStyle.Flat,
                light =
                    StyleSchemeTokens(
                        bg = "#FAFAF8",
                        surface = STYLE_SURFACE_COLOR_WHITE,
                        text = "#1B1B18",
                        muted = "#5E5E58",
                        line = "#E4E4DF",
                        track = "#EDEDE8",
                        income = "#2F6B4F",
                        shadow = STYLE_CARD_SHADOW_NONE,
                    ),
                dark =
                    StyleSchemeTokens(
                        bg = "#121211",
                        surface = "#1B1B19",
                        text = "#F2F2EE",
                        muted = "#A7A7A0",
                        line = "#2E2E2B",
                        track = "#2A2A27",
                        income = "#8CCBA6",
                        shadow = STYLE_CARD_SHADOW_NONE,
                    ),
            ),
        ThemeStyle.Calm to
            StyleTokens(
                title = "落ち着いた・大人っぽい",
                defaultAccent = ThemeColor.Sage,
                bodyFont = FONT_STACK_ZEN_KAKU_GOTHIC_NEW,
                headFont = "'Shippori Mincho B1', 'Hiragino Mincho ProN', serif",
                numWeight = 700,
                radius = 4,
                btnRadius = 4,
                chipRadius = 3,
                card = CardStyle.Border,
                list = ListStyle.Card,
                light =
                    StyleSchemeTokens(
                        bg = "#F3EFE6",
                        surface = "#FBF9F4",
                        text = "#1E2A2A",
                        muted = "#566060",
                        line = "#D8D1C2",
                        track = "#E4DDCF",
                        income = "#2C5545",
                        shadow = STYLE_CARD_SHADOW_NONE,
                    ),
                dark =
                    StyleSchemeTokens(
                        bg = "#151B1C",
                        surface = "#1D2526",
                        text = "#ECE7DC",
                        muted = "#AAB1AD",
                        line = "#2F3A3B",
                        track = "#2A3435",
                        income = "#9CC7B2",
                        shadow = STYLE_CARD_SHADOW_NONE,
                    ),
            ),
        ThemeStyle.Bright to
            StyleTokens(
                title = "元気・カラフル",
                defaultAccent = ThemeColor.Soda,
                bodyFont = "'M PLUS Rounded 1c', 'Hiragino Maru Gothic ProN', sans-serif",
                headFont = "'M PLUS Rounded 1c', 'Hiragino Maru Gothic ProN', sans-serif",
                numWeight = 800,
                radius = 18,
                btnRadius = 16,
                chipRadius = 999,
                card = CardStyle.Shadow,
                list = ListStyle.Card,
                light =
                    StyleSchemeTokens(
                        bg = "#FFFBF5",
                        surface = STYLE_SURFACE_COLOR_WHITE,
                        text = "#1C1C28",
                        muted = "#555566",
                        line = "#ECE8F3",
                        track = "rgba(255,255,255,0.35)",
                        income = "#15803D",
                        shadow = "0 6px 16px rgba(40,30,80,0.08)",
                    ),
                dark =
                    StyleSchemeTokens(
                        bg = "#16151F",
                        surface = "#22202E",
                        text = "#F5F3FF",
                        muted = "#BAB6CF",
                        line = "#34314A",
                        track = "rgba(0,0,0,0.25)",
                        income = "#6EE7A0",
                        shadow = "0 6px 16px rgba(0,0,0,0.4)",
                    ),
            ),
        ThemeStyle.Cute to
            StyleTokens(
                title = "かわいい",
                defaultAccent = ThemeColor.Rose,
                bodyFont = FONT_STACK_ZEN_MARU_GOTHIC,
                headFont = "'Kiwi Maru', 'Hiragino Maru Gothic ProN', serif",
                numWeight = 500,
                radius = 28,
                btnRadius = 999,
                chipRadius = 999,
                card = CardStyle.Shadow,
                list = ListStyle.Card,
                light =
                    StyleSchemeTokens(
                        bg = "#FFF6F8",
                        surface = STYLE_SURFACE_COLOR_WHITE,
                        text = "#4A3A44",
                        muted = "#76636F",
                        line = "#F4DCE4",
                        track = "#FBE7EE",
                        income = "#2E7D5B",
                        shadow = "0 6px 0 rgba(200,120,150,0.12)",
                    ),
                dark =
                    StyleSchemeTokens(
                        bg = "#241B21",
                        surface = "#30252C",
                        text = "#FBEFF4",
                        muted = "#D0B9C5",
                        line = "#46373F",
                        track = "#3E3139",
                        income = "#86D5AE",
                        shadow = "0 6px 0 rgba(0,0,0,0.35)",
                    ),
            ),
    )

/** The colour scheme's own fixed text colour on an accent surface (takamai `onAccent`). */
val onAccent: Map<ThemeScheme, String> =
    mapOf(
        ThemeScheme.Light to STYLE_SURFACE_COLOR_WHITE,
        ThemeScheme.Dark to "#141210",
    )

/**
 * "dark mode uses the colour mixed 45% toward white" (darkModeRule); light
 * mode uses the colour as-is (takamai `accentMixTowardWhite`).
 */
val accentMixTowardWhite: Map<ThemeScheme, Double> =
    mapOf(
        ThemeScheme.Light to 0.0,
        ThemeScheme.Dark to 0.45,
    )

/** tint: "light: colour mixed 88% toward white; dark: ... 12% ... at alpha 0x44" (takamai `tintMixTowardWhite`). */
val tintMixTowardWhite: Map<ThemeScheme, Double> =
    mapOf(
        ThemeScheme.Light to 0.88,
        ThemeScheme.Dark to 0.12,
    )

/** The alpha channel (as a two-digit hex suffix) appended to the dark tint (takamai `TINT_DARK_ALPHA`). */
const val TINT_DARK_ALPHA: String = "44"

/**
 * glass: the surface colour's own alpha suffix, per scheme (takamai
 * `glassSurfaceAlpha`; see that constant's own doc comment in tokens.ts
 * for the stage-7 a11y fix behind the light value).
 */
val glassSurfaceAlpha: Map<ThemeScheme, String> =
    mapOf(
        ThemeScheme.Light to "EB",
        ThemeScheme.Dark to "B8",
    )

/**
 * takamai `glassBorder`: not a hex colour, a raw CSS `rgba()` string - kept
 * as data, not mapped to a platform colour yet.
 */
val glassBorder: Map<ThemeScheme, String> =
    mapOf(
        ThemeScheme.Light to "rgba(255,255,255,0.75)",
        ThemeScheme.Dark to "rgba(255,255,255,0.10)",
    )

/** takamai `glassShadow`: each layer reaches at most `FLOATING_BAR_SHADOW_REACH` below the capsule. */
val glassShadow: Map<ThemeScheme, String> =
    mapOf(
        ThemeScheme.Light to "0 -2px 22px rgba(30,20,10,0.10), 0 6px 14px rgba(30,20,10,0.10)",
        ThemeScheme.Dark to "0 -2px 22px rgba(0,0,0,0.40), 0 6px 14px rgba(0,0,0,0.35)",
    )

/** What a user who never chose has (takamai `defaultStyle`; matches takamai backend's `DefaultAppearance`). */
val defaultStyle: ThemeStyle = ThemeStyle.Soft

/** What a user who never chose has (takamai `defaultColor`; matches takamai backend's `DefaultAppearance`). */
val defaultColor: ThemeColor = ThemeColor.Terracotta

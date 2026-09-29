package io.github.mktkhr.moneging.acceptance

import kotlin.time.Clock
import kotlin.time.Instant

/** The ledger of PRODUCT.md §7's shared fixtures. */
internal const val FIXTURE_LEDGER_NAME = "家計"

/** The device identifier the acceptance tests inject (AC-B-108's `D`). */
internal const val FIXTURE_DEVICE_ID = "D"

/** 2026-02-15 12:00 in Asia/Tokyo: the fixtures' clock (PRODUCT.md §7). */
internal val FIXTURE_NOON: Instant = Instant.parse("2026-02-15T12:00:00+09:00")

/** 2026-02-15 12:05 in Asia/Tokyo: where AC-B-108 moves the clock. */
internal val FIXTURE_NOON_PLUS_FIVE: Instant = Instant.parse("2026-02-15T12:05:00+09:00")

/** The default categories of every new ledger, in PRODUCT.md §3's order. */
internal val DEFAULT_CATEGORY_NAMES: List<String> =
    listOf(
        "食費",
        "日用品",
        "住居",
        "水道光熱費",
        "交通費",
        "通信費",
        "医療",
        "教育",
        "娯楽",
        "交際費",
        "衣服",
        "その他",
    )

/**
 * A [Clock] the test sets by hand: the shared logic reads time only through
 * the injected clock (PRODUCT.md §6, determinism in tests).
 */
internal class ManualClock(
    /** The instant [now] returns until it is changed. */
    var current: Instant,
) : Clock {
    override fun now(): Instant = current
}

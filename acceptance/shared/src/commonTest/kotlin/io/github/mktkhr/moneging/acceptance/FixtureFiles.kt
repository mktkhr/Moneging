package io.github.mktkhr.moneging.acceptance

// Reading acceptance/fixtures from the tests, on the Android host and on the
// iOS simulator alike (both see the host's file system).

/** The environment variable holding the absolute path of `acceptance/fixtures`; `make acceptance-shared` sets it. */
internal const val FIXTURES_ENVIRONMENT_VARIABLE = "MONEGING_FIXTURES"

/**
 * The bytes of [relativePath] under `acceptance/fixtures` (`receipts/seven-eleven.jpg`), read from
 * the directory [FIXTURES_ENVIRONMENT_VARIABLE] names, else from the nearest `fixtures` or
 * `acceptance/fixtures` above the working directory.
 */
internal expect fun readFixtureFile(relativePath: String): ByteArray

/** The text of the UTF-8 file [relativePath] under `acceptance/fixtures`. */
internal fun readFixtureText(relativePath: String): String = readFixtureFile(relativePath).decodeToString()

/** The nearest directory at or above [start] that holds `fixtures` or `acceptance/fixtures`, as [isFixtures] judges. */
internal fun findFixturesDirectory(
    start: String,
    isFixtures: (String) -> Boolean,
): String? =
    generateSequence(
        seed = start,
    ) { directory ->
        directory.substringBeforeLast(delimiter = '/', missingDelimiterValue = "").ifEmpty {
            null
        }
    }.flatMap { directory -> sequenceOf("$directory/fixtures", "$directory/acceptance/fixtures") }
        .firstOrNull(predicate = isFixtures)

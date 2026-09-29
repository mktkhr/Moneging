package io.github.mktkhr.moneging.data

import kotlin.time.Instant
import kotlin.uuid.Uuid

// How values are kept in the database's columns: instants as epoch
// milliseconds, booleans as 0/1, identifiers and calendar values as their
// ISO text.

private const val SQL_TRUE = 1L
private const val SQL_FALSE = 0L

internal fun Instant.toColumn(): Long = toEpochMilliseconds()

internal fun Long.toInstant(): Instant = Instant.fromEpochMilliseconds(this)

internal fun Boolean.toColumn(): Long = if (this) SQL_TRUE else SQL_FALSE

internal fun Long.toBoolean(): Boolean = this != SQL_FALSE

internal fun String.toUuid(): Uuid = Uuid.parse(this)

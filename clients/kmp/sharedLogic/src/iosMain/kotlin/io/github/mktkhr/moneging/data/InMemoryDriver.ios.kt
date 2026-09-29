package io.github.mktkhr.moneging.data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import io.github.mktkhr.moneging.data.db.MonegingDatabase
import kotlin.uuid.Uuid

// Named uniquely: SQLite shares an in-memory database between connections
// of the same name, and every store must start empty.
internal actual fun inMemoryDriver(): SqlDriver =
    NativeSqliteDriver(
        schema = MonegingDatabase.Schema,
        name = "memory-${Uuid.random()}.db",
        onConfiguration = { configuration -> configuration.copy(inMemory = true) },
    )

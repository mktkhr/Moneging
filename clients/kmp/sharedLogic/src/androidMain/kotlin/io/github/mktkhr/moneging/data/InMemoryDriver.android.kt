package io.github.mktkhr.moneging.data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import io.github.mktkhr.moneging.data.db.MonegingDatabase

// The JVM's SQLite: the Android host tests run without an Android framework,
// where the platform's SQLite is not available. The app never calls this.
internal actual fun inMemoryDriver(): SqlDriver =
    JdbcSqliteDriver(url = JdbcSqliteDriver.IN_MEMORY, schema = MonegingDatabase.Schema)

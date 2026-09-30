package io.github.mktkhr.moneging.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import io.github.mktkhr.moneging.data.db.MonegingDatabase
import io.github.mktkhr.moneging.scan.ReadingMethods
import java.io.File
import kotlin.time.Clock
import kotlin.uuid.Uuid

private const val DATABASE_NAME = "moneging.db"
private const val PHOTOS_DIRECTORY_NAME = "photos"
private const val PREFERENCES_NAME = "moneging"
private const val GEMINI_NANO = "Gemini Nano"

/** The store in the app's private storage on [clock], stamping records with [preferences]' device identifier. */
internal fun onDiskStore(
    context: Context,
    preferences: Preferences,
    clock: Clock,
): LocalStore {
    // The database stays open for the app's lifetime, owned by the store.
    fun openDriver(): SqlDriver =
        AndroidSqliteDriver(schema = MonegingDatabase.Schema, context = context, name = DATABASE_NAME)
    return LocalStore(
        openDriver = ::openDriver,
        clock = clock,
        deviceId = deviceId(preferences),
        photoFiles = DirectoryPhotoFiles(File(context.filesDir, PHOTOS_DIRECTORY_NAME)),
        // Gemini Nano is not wired yet: reading uses no AI until it is.
        scanning =
            Scanning(
                readingMethods = ReadingMethods(llm = null, preferences = preferences, aiName = GEMINI_NANO),
            ),
    )
}

/** Photo bytes kept as files named by the photo's identifier in [directory]. */
internal class DirectoryPhotoFiles(
    private val directory: File,
) : PhotoFiles {
    override fun write(
        id: Uuid,
        bytes: ByteArray,
    ) {
        directory.mkdirs()
        File(directory, id.toString()).writeBytes(bytes)
    }

    override fun read(id: Uuid): ByteArray? = File(directory, id.toString()).takeIf { it.isFile }?.readBytes()

    override fun delete(id: Uuid) {
        File(directory, id.toString()).delete()
    }

    override fun ids(): Set<Uuid> =
        directory
            .listFiles()
            .orEmpty()
            .mapNotNull { file -> Uuid.parseOrNull(file.name) }
            .toSet()
}

/** [Preferences] in the app's private shared preferences. */
internal class SharedPreferencesStore(
    context: Context,
) : Preferences {
    private val preferences: SharedPreferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun string(key: String): String? = preferences.getString(key, null)

    override fun setString(
        key: String,
        value: String?,
    ) {
        preferences.edit { if (value == null) remove(key) else putString(key, value) }
    }
}

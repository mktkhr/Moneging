package io.github.mktkhr.moneging.data

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import io.github.mktkhr.moneging.data.db.MonegingDatabase
import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.Foundation.NSApplicationSupportDirectory
import platform.Foundation.NSData
import platform.Foundation.NSFileManager
import platform.Foundation.NSUserDefaults
import platform.Foundation.NSUserDomainMask
import platform.Foundation.create
import platform.Foundation.writeToFile
import kotlin.time.Clock
import kotlin.uuid.Uuid

private const val DIRECTORY_NAME = "Moneging"
private const val DATABASE_NAME = "moneging.db"
private const val PHOTOS_DIRECTORY_NAME = "photos"

/**
 * The directory holding the app's data on this device: the database and the
 * photos. It lives in Application Support, which the iCloud device backup
 * includes.
 */
@OptIn(ExperimentalForeignApi::class)
fun localDataDirectory(): String {
    val base =
        NSFileManager.defaultManager.URLForDirectory(
            directory = NSApplicationSupportDirectory,
            inDomain = NSUserDomainMask,
            appropriateForURL = null,
            create = true,
            error = null,
        )
    return checkNotNull(base?.path) { "Application Support がありません" } + "/" + DIRECTORY_NAME
}

/**
 * The store kept in [directory] (created if missing) on [clock], stamping
 * records with [preferences]' device identifier.
 */
@OptIn(ExperimentalForeignApi::class)
internal fun onDiskStore(
    directory: String,
    preferences: Preferences,
    clock: Clock,
): LocalStore {
    val photos = "$directory/$PHOTOS_DIRECTORY_NAME"
    NSFileManager.defaultManager.createDirectoryAtPath(
        path = photos,
        withIntermediateDirectories = true,
        attributes = null,
        error = null,
    )

    // The database stays open for the app's lifetime, owned by the store.
    fun openDriver(): SqlDriver =
        NativeSqliteDriver(
            schema = MonegingDatabase.Schema,
            name = DATABASE_NAME,
            onConfiguration = { configuration ->
                configuration.copy(extendedConfig = configuration.extendedConfig.copy(basePath = directory))
            },
        )
    return LocalStore(
        openDriver = ::openDriver,
        clock = clock,
        deviceId = deviceId(preferences),
        photoFiles = DirectoryPhotoFiles(photos),
    )
}

/** Photo bytes kept as files named by the photo's identifier in [directory]. */
internal class DirectoryPhotoFiles(
    private val directory: String,
) : PhotoFiles {
    @OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)
    override fun write(
        id: Uuid,
        bytes: ByteArray,
    ) {
        val data =
            bytes.usePinned { pinned ->
                NSData.create(bytes = pinned.addressOf(0), length = bytes.size.toULong())
            }
        check(data.writeToFile(path = "$directory/$id", atomically = true)) { "写真を保存できませんでした" }
    }
}

/** [Preferences] in the app's user defaults. */
internal class UserDefaultsPreferences(
    private val defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults,
) : Preferences {
    override fun string(key: String): String? = defaults.stringForKey(key)

    override fun setString(
        key: String,
        value: String?,
    ) {
        if (value == null) defaults.removeObjectForKey(key) else defaults.setObject(value, forKey = key)
    }

    /** Removes every value this app keeps. */
    fun clear() {
        listOf(
            PreferenceKeys.LEDGER_IN_VIEW,
            PreferenceKeys.TOUR_NEXT_STEP,
            PreferenceKeys.DEVICE_ID,
        ).forEach { defaults.removeObjectForKey(it) }
    }
}

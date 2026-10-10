package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.data.PreferenceKeys
import io.github.mktkhr.moneging.data.UserDefaultsPreferences
import io.github.mktkhr.moneging.data.localDataDirectory
import io.github.mktkhr.moneging.data.markReviewNeeded
import io.github.mktkhr.moneging.data.toByteArray
import io.github.mktkhr.moneging.data.todayInTokyo
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.scan.FixtureReceipt
import io.github.mktkhr.moneging.scan.FixtureReceiptScanner
import io.github.mktkhr.moneging.scan.FoundationModelsLlm
import io.github.mktkhr.moneging.scan.IosReceiptReader
import io.github.mktkhr.moneging.scan.NoModuleInstaller
import io.github.mktkhr.moneging.scan.ReadingMethod
import io.github.mktkhr.moneging.scan.ReadingModuleInstaller
import io.github.mktkhr.moneging.scan.ReceiptReading
import io.github.mktkhr.moneging.scan.ScanPacer
import io.github.mktkhr.moneging.scan.iosReceiptScanner
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atTime
import kotlinx.datetime.toInstant
import org.koin.mp.KoinPlatform
import platform.Foundation.NSData
import platform.Foundation.NSFileManager
import platform.Foundation.dataWithContentsOfFile
import kotlin.time.Clock
import kotlin.time.Instant
import kotlin.time.TimeSource
import kotlin.uuid.Uuid

private const val NOON = 12
private const val SEEDED_TRANSACTION_COUNT = 24
private const val SEEDED_AMOUNT_STEP = 100L

// Called only from the iOS app's debug builds (`#if DEBUG`), on a UI test's
// launch argument: the release app never calls them.

/**
 * Deletes everything the app keeps on the device (the database, the photos,
 * the ledger in view, the tour's progress, the device identifier), so the
 * app starts as freshly installed. Must run before [initKoin].
 */
@OptIn(ExperimentalForeignApi::class)
fun resetLocalDataForUiTests() {
    check(KoinPlatform.getKoinOrNull() == null) { "initKoin より前に呼んでください" }
    NSFileManager.defaultManager.removeItemAtPath(localDataDirectory(), error = null)
    UserDefaultsPreferences().clear()
}

/**
 * Starts the shared Koin container, like [initKoin], for a UI test: on a
 * clock that reads [isoDate] (`2026-02-15`) at 12:00 in Asia/Tokyo when the
 * app launches and advances with the time elapsed since (the device's clock
 * when `null`); reading receipts with the fixture scanner over the fixtures
 * directory [scannerFixtures] (`acceptance/fixtures`) when given, else with
 * [reader]; moving scan jobs only on [stepScanJobsForUiTests] when
 * [isJobStepping]; and downloading through [installer] (none when `null`).
 */
fun initKoinForUiTests(
    isoDate: String?,
    reader: IosReceiptReader,
    scannerFixtures: String?,
    isJobStepping: Boolean,
    installer: ReadingModuleInstaller?,
) {
    val clock =
        isoDate?.let { date ->
            val launchedAt = LocalDate.parse(date).atTime(hour = NOON, minute = 0).toInstant(TimeZone.of("Asia/Tokyo"))
            val sinceLaunch = TimeSource.Monotonic.markNow()
            object : Clock {
                override fun now(): Instant = launchedAt + sinceLaunch.elapsedNow()
            }
        } ?: Clock.System
    val pacer = if (isJobStepping) ScanPacer.Stepped().also { steppedPacer = it } else ScanPacer.Immediate
    startIosKoin(
        clock = clock,
        llm = FoundationModelsLlm(reader),
        scanner = scannerFixtures?.let { fixtureScanner(directory = it) } ?: iosReceiptScanner(reader),
        scanPacer = pacer,
        installer = installer ?: NoModuleInstaller,
    )
}

// The pacer of a UI test that steps its scan jobs, or `null`.
private var steppedPacer: ScanPacer.Stepped? = null

/** Moves every unfinished scan job one state on, in a UI test that steps them. */
fun stepScanJobsForUiTests() {
    steppedPacer?.step()
}

/**
 * Sets the reading method, as if chosen in the settings: the device's AI when
 * [deviceAi], else `AI を使わない`. Must run before [initKoin].
 */
fun chooseReadingMethodForUiTests(deviceAi: Boolean) {
    val method = if (deviceAi) ReadingMethod.DEVICE_AI else ReadingMethod.NO_AI
    UserDefaultsPreferences().setString(key = PreferenceKeys.READING_METHOD, value = method.name)
}

/** Enables reading receipts from photos, as if chosen in the onboarding; must run before the app state is resolved. */
fun enablePhotoReadingForUiTests() {
    UserDefaultsPreferences().setString(key = PreferenceKeys.PHOTO_READING, value = PreferenceKeys.PHOTO_READING_ON)
}

// The fixture scanner over `<directory>/receipts`: each picture beside its draft (`<name>.jpg`, `<name>.json`).
@OptIn(ExperimentalForeignApi::class)
private fun fixtureScanner(directory: String): FixtureReceiptScanner {
    val receipts = "$directory/receipts"
    val names =
        NSFileManager.defaultManager
            .contentsOfDirectoryAtPath(receipts, error = null)
            .orEmpty()
            .mapNotNull { (it as? String)?.removeSuffix(suffix = ".json")?.takeIf { name -> name != it } }
    return FixtureReceiptScanner(
        receipts =
            names.mapNotNull { name ->
                val image = NSData.dataWithContentsOfFile("$receipts/$name.jpg")?.toByteArray()
                val json = NSData.dataWithContentsOfFile("$receipts/$name.json")?.toByteArray()?.decodeToString()
                if (image == null ||
                    json == null
                ) {
                    null
                } else {
                    FixtureReceipt(image = image, reading = ReceiptReading.fromJson(json))
                }
            },
    )
}

/**
 * Creates the ledgers [names], in order, with the first in view and the
 * tour finished, for UI tests that start past the onboarding; [withTransactions]
 * also records, in the first, [SEEDED_TRANSACTION_COUNT] expenses of 食費 dated
 * today, memos `記録01` onwards. Must run after [initKoin] and before the app
 * state is first resolved.
 */
fun seedLedgersForUiTests(
    names: List<String>,
    withTransactions: Boolean,
) {
    val koin = KoinPlatform.getKoin()
    val store = koin.get<LocalStore>()
    val today = koin.get<Clock>().todayInTokyo()
    val preferences = UserDefaultsPreferences()
    val ledgers = runBlocking { names.map { store.createLedger(it) } }
    val first = ledgers.firstOrNull()
    if (withTransactions && first != null) {
        runBlocking {
            val scope = store.ledger(first.id)
            val food = scope.categories().first().id
            for (number in 1..SEEDED_TRANSACTION_COUNT) {
                scope.recordTransaction(
                    NewTransaction(
                        date = today,
                        direction = Direction.EXPENSE,
                        amount = number * SEEDED_AMOUNT_STEP,
                        categoryId = food,
                        memo = "記録" + number.toString().padStart(length = 2, padChar = '0'),
                    ),
                )
            }
        }
    }
    preferences.setString(key = PreferenceKeys.LEDGER_IN_VIEW, value = ledgers.firstOrNull()?.id?.toString())
    preferences.setString(key = PreferenceKeys.TOUR_NEXT_STEP, value = PreferenceKeys.TOUR_FINISHED)
}

/**
 * Once the onboarding has created the first ledger, records into it two
 * expenses marked needs-review, as if drafts had been confirmed with their
 * mismatch accepted: 980 on 2026-02-13 at コーナーデリ in 食費 (唐揚げ弁当 680,
 * 緑茶 150, 差額 150) and 2,640 on 2026-01-20 at ドラッグストア みどり in 日用品
 * (洗剤 2,000, 差額 640). Must run after [initKoin].
 */
fun seedReviewRecordsForUiTests() {
    val store = KoinPlatform.getKoin().get<LocalStore>()
    CoroutineScope(Dispatchers.Default).launch {
        val ledger = store.observeLedgers().first { it.isNotEmpty() }.first()
        val scope = store.ledger(ledger.id)
        val deli =
            scope.recordSplit(
                date = "2026-02-13",
                storeName = "コーナーデリ",
                category = "食費",
                items = listOf("唐揚げ弁当" to 680L, "緑茶" to 150L, "差額" to 150L),
            )
        val drugstore =
            scope.recordSplit(
                date = "2026-01-20",
                storeName = "ドラッグストア みどり",
                category = "日用品",
                items = listOf("洗剤" to 2_000L, "差額" to 640L),
            )
        listOf(deli, drugstore).forEach { id -> store.markReviewNeeded(ledgerId = ledger.id, transactionId = id) }
    }
}

// Records an expense of [items] (name to amount), all in the category named [category]; returns its id.
private suspend fun LedgerScope.recordSplit(
    date: String,
    storeName: String,
    category: String,
    items: List<Pair<String, Long>>,
): Uuid {
    val categoryId = categories().first { it.name == category }.id
    return recordTransaction(
        NewTransaction(
            date = LocalDate.parse(date),
            direction = Direction.EXPENSE,
            amount = items.sumOf { it.second },
            categoryId = null,
            storeName = storeName,
            items = items.map { (name, amount) -> NewLineItem(amount = amount, categoryId = categoryId, name = name) },
        ),
    ).id
}

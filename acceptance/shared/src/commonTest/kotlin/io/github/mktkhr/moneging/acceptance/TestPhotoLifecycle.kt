package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Photo
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.uuid.Uuid

private const val PHOTO_SIZE = 12_288
private const val PATTERN_STEP = 31
private const val EXPENSE_AMOUNT = 1_180L
private const val MARKER_PREFIX: Byte = -1 // 0xFF
private const val JPEG_START: Byte = -40 // 0xD8
private const val JPEG_END: Byte = -39 // 0xD9

/**
 * AC-B-501 — A photo is kept, listed and deleted, and its bytes go with it.
 *
 * Given a 12 KiB JPEG (12,288 bytes) kept in the ledger as `image/jpeg`. When
 * the list is read, then it holds one photo of 12,288 bytes with content type
 * `image/jpeg`. When its bytes are read, then they are byte-identical to what
 * was kept. When it is deleted, then the list is empty, reading its bytes
 * finds nothing, and they are gone from the app's storage. Given a photo
 * referenced by a transaction, when it is deleted, then the deletion is
 * refused as a conflict and both the photo and its bytes remain.
 */
class TestPhotoLifecycle {
    /** A photo is kept, listed, read back and deleted with its bytes; one a transaction refers to is not deleted. */
    @Test
    fun photoIsKeptListedAndDeleted(): TestResult =
        runTest {
            assertKeptAndDeleted()
            assertReferencedPhotoStays()
        }

    private suspend fun assertKeptAndDeleted() {
        val ledger = scanningLedger()
        val scope = ledger.scope
        val bytes = twelveKibJpeg()
        val kept = scope.addPhoto(bytes = bytes, contentType = JPEG, capturedAt = FIXTURE_NOON)

        assertKept(scope = scope, kept = kept, bytes = bytes)

        scope.deletePhoto(id = kept.id)

        assertGone(ledger = ledger, id = kept.id)
    }

    // A photo a transaction refers to cannot be deleted: the photo and its bytes stay.
    private suspend fun assertReferencedPhotoStays() {
        val ledger = scanningLedger()
        val scope = ledger.scope
        val bytes = twelveKibJpeg()
        val kept = scope.addPhoto(bytes = bytes, contentType = JPEG, capturedAt = FIXTURE_NOON)
        scope.recordTransaction(
            transaction =
                NewTransaction(
                    date = LocalDate.parse("2026-02-14"),
                    direction = Direction.EXPENSE,
                    amount = EXPENSE_AMOUNT,
                    categoryId = scope.categoryIdNamed(name = "食費"),
                    photoId = kept.id,
                ),
        )

        assertFailsWith<IllegalStateException>(message = "取引が参照する写真を削除できてしまう") {
            scope.deletePhoto(id = kept.id)
        }

        assertEquals(expected = listOf(kept), actual = scope.photos(), message = "拒否された削除で写真の一覧が変わった")
        assertContentEquals(
            expected = bytes,
            actual = scope.photoBytes(id = kept.id),
            message = "拒否された削除で写真のバイトが変わった",
        )
        assertTrue(actual = kept.id in ledger.store.storedPhotoIds(), message = "拒否された削除で保存領域のバイトが消えた")
    }
}

// 12,288 bytes that look like a JPEG (start and end markers) and differ from each other.
private fun twelveKibJpeg(): ByteArray =
    ByteArray(size = PHOTO_SIZE) { index -> (index * PATTERN_STEP).toByte() }.also { bytes ->
        bytes[0] = MARKER_PREFIX
        bytes[1] = JPEG_START
        bytes[PHOTO_SIZE - 2] = MARKER_PREFIX
        bytes[PHOTO_SIZE - 1] = JPEG_END
    }

// The list holds this one photo, of 12,288 bytes and type image/jpeg, whose bytes read back identical.
private suspend fun assertKept(
    scope: LedgerScope,
    kept: Photo,
    bytes: ByteArray,
) {
    val listed = scope.photos()
    assertEquals(expected = 1, actual = listed.size, message = "写真の一覧が 1 枚でない")
    assertEquals(
        expected = PHOTO_SIZE.toLong(),
        actual = listed.single().sizeBytes,
        message = "写真が 12,288 バイトでない",
    )
    assertEquals(expected = JPEG, actual = listed.single().contentType, message = "写真の種類が image/jpeg でない")
    assertEquals(expected = kept.id, actual = listed.single().id, message = "一覧の写真が保存した写真でない")
    val read = assertNotNull(actual = scope.photoBytes(id = kept.id), message = "保存した写真のバイトが読めない")
    assertContentEquals(expected = bytes, actual = read, message = "写真のバイトが保存したものと一致しない")
}

// A deleted photo is not listed, its bytes are not read and not in the storage.
private suspend fun assertGone(
    ledger: ScanningLedger,
    id: Uuid,
) {
    assertTrue(actual = ledger.scope.photos().isEmpty(), message = "削除しても写真の一覧が空にならない")
    assertNull(actual = ledger.scope.photoBytes(id = id), message = "削除した写真のバイトが読める")
    assertFalse(
        actual = id in ledger.store.storedPhotoIds(),
        message = "削除した写真のバイトがアプリの保存領域に残っている",
    )
}

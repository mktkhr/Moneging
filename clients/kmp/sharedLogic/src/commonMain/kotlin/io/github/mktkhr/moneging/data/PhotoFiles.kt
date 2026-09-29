package io.github.mktkhr.moneging.data

import kotlin.uuid.Uuid

/** Where photo bytes live: the app's private storage, or memory in tests. */
internal fun interface PhotoFiles {
    /** Stores [bytes] as the photo [id]. */
    fun write(
        id: Uuid,
        bytes: ByteArray,
    )
}

/** Photo bytes held in memory, for [LocalStore.inMemory]. */
internal class InMemoryPhotoFiles : PhotoFiles {
    private val files = mutableMapOf<Uuid, ByteArray>()

    override fun write(
        id: Uuid,
        bytes: ByteArray,
    ) {
        files[id] = bytes.copyOf()
    }
}

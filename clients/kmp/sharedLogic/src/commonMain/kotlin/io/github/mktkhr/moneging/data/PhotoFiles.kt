package io.github.mktkhr.moneging.data

import kotlin.uuid.Uuid

/** Where photo bytes live: the app's private storage, or memory in tests. */
internal interface PhotoFiles {
    /** Stores [bytes] as the photo [id]. */
    fun write(
        id: Uuid,
        bytes: ByteArray,
    )

    /** The bytes of the photo [id], or `null` when none are stored. */
    fun read(id: Uuid): ByteArray?

    /** Removes the bytes of the photo [id], if any. */
    fun delete(id: Uuid)

    /** The photos whose bytes are stored. */
    fun ids(): Set<Uuid>
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

    override fun read(id: Uuid): ByteArray? = files[id]?.copyOf()

    override fun delete(id: Uuid) {
        files.remove(id)
    }

    override fun ids(): Set<Uuid> = files.keys.toSet()
}

package io.github.mktkhr.moneging.scan

/**
 * A module a device downloads to read receipts from photos (PRODUCT.md §3,
 * Photo reading). Only Android downloads any; iOS's are part of the OS.
 */
enum class ReadingModule {
    /** The ML Kit document scanner. */
    DOCUMENT_SCANNER,

    /** ML Kit text recognition. */
    TEXT_RECOGNITION,

    /** Gemini Nano, on a device that supports it. */
    GEMINI_NANO,
}

/** Downloads reading modules (through Google Play services on Android). */
fun interface ReadingModuleInstaller {
    /** Asks for [modules] to be downloaded. */
    fun requestInstall(modules: List<ReadingModule>)
}

/** The installer of a device that downloads nothing: it is never asked, since no module is needed. */
object NoModuleInstaller : ReadingModuleInstaller {
    override fun requestInstall(modules: List<ReadingModule>) {
        // Nothing to download: the device needs no module.
    }
}

package io.github.mktkhr.moneging

import platform.UIKit.UIDevice

/**
 * iOS implementation of [Platform], reporting the running OS version.
 */
class IOSPlatform : Platform {
    override val name: String = "${UIDevice.currentDevice.systemName()} ${UIDevice.currentDevice.systemVersion}"
}

/**
 * Returns the iOS [Platform] implementation.
 */
actual fun getPlatform(): Platform = IOSPlatform()

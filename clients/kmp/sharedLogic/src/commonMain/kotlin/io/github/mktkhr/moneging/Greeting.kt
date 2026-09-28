package io.github.mktkhr.moneging

/**
 * Builds a platform-aware greeting message.
 */
class Greeting {
    private val platform = getPlatform()

    /**
     * Returns a greeting that names the current [Platform].
     */
    fun greet(): String = sayHello(platform.name)
}

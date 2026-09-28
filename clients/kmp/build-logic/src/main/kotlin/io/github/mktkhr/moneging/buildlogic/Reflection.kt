package io.github.mktkhr.moneging.buildlogic

import org.gradle.api.provider.Provider

/**
 * Reads a private field declared anywhere in the object's class hierarchy
 * (e.g. the unfiltered source roots of a SourceTask).
 */
internal fun Any.privateField(name: String): Any? {
    val field =
        generateSequence<Class<*>>(javaClass) { it.superclass }
            .firstNotNullOfOrNull { type -> type.declaredFields.firstOrNull { it.name == name } }
            ?: return null
    field.isAccessible = true
    return field.get(this)
}

/**
 * The value of a provider reached through its getter's JVM name: a Kotlin
 * `internal` (name-mangled) property of a tool plugin's task, or one whose
 * value type is not on this build's compile classpath.
 */
internal fun Any.providerValue(getter: String): Any? = (javaClass.getMethod(getter).invoke(this) as Provider<*>).orNull

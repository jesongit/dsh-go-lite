package io.github.ccch1mneyyy.dsh_app.performance

/** Shared only within this process. The thermal listener keeps the latest effective performance mode. */
internal object ThermalRuntime {
    @Volatile var lightweight: Boolean? = null
}

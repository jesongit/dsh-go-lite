package io.github.ccch1mneyyy.dsh_app.pet

/** Real, unobscured input after the approval bubble is armed; TalkBack remains usable. */
internal object PromptInputPolicy {
    fun allows(now: Long, armedAt: Long, live: Boolean, obscured: Boolean,
               virtualDevice: Boolean, suspiciousStroke: Boolean, touchExploration: Boolean): Boolean =
        live && now >= armedAt && !obscured && !(virtualDevice && suspiciousStroke && !touchExploration)
}

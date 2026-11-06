package io.github.ccch1mneyyy.dsh_app.performance

import org.junit.Assert.*
import org.junit.Test

class PerformanceRulesTest {
    private val high = DeviceProfile(
        lowRam = false, totalMemoryBytes = 8L * 1024 * PerformanceRules.MIB,
        cpuCores = 8, availableProcessors = 8, sdkInt = 35, mediaPerformanceClass = 35,
    )

    @Test fun androidLowRamWinsOverOtherHighCapacitySignals() {
        assertEquals(DeviceTier.LOW, PerformanceRules.classify(high.copy(lowRam = true)))
        assertTrue(PerformanceRules.reasons(high.copy(lowRam = true)).contains("android_low_ram"))
    }

    @Test fun existingOnboardingMemoryBoundaryIsExact() {
        assertEquals(DeviceTier.LOW, PerformanceRules.classify(high.copy(totalMemoryBytes = PerformanceRules.LOW_MEMORY_BYTES - 1)))
        assertEquals(DeviceTier.HIGH, PerformanceRules.classify(high.copy(totalMemoryBytes = PerformanceRules.LOW_MEMORY_BYTES)))
    }

    @Test fun twoCoresGetAConservativeDefaultEvenWithPlentyOfRam() {
        assertEquals(DeviceTier.LOW, high.copy(cpuCores = 2).tier)
        assertEquals(DeviceTier.MEDIUM, high.copy(cpuCores = 3).tier)
        assertEquals(DeviceTier.HIGH, high.copy(cpuCores = 4).tier)
    }

    @Test fun missingDataIsNotInventedAsLowOrCertifiedHigh() {
        assertEquals(DeviceTier.MEDIUM, DeviceProfile().tier)
        assertEquals(DeviceTier.MEDIUM, high.copy(totalMemoryBytes = null).tier)
        assertEquals(DeviceTier.MEDIUM, high.copy(cpuCores = null).tier)
        assertEquals(DeviceTier.MEDIUM, high.copy(mediaPerformanceClass = 0).tier)
        assertEquals(DeviceTier.MEDIUM, high.copy(mediaPerformanceClass = 30).tier)
        assertEquals(DeviceTier.MEDIUM, high.copy(sdkInt = 30).tier)
    }

    @Test fun clockFrequencyIsDiagnosticNotACrossArchitectureBenchmark() {
        assertEquals(high.tier, high.copy(cpuMaxKhz = listOf(null, 1_000_000)).tier)
        assertEquals(high.tier, high.copy(cpuMaxKhz = listOf(4_000_000)).tier)
        assertEquals(listOf(4_000_000L), high.copy(cpuMaxKhz = listOf(4_000_000)).toMap()["cpuMaxKhz"])
    }

}

package org.nslabs.ir_blaster

import org.junit.Assert.*
import org.junit.Test

class AutomationIrRequestTest {
    @Test fun acceptsCommaAndWhitespaceDurationsWithoutChangingThem() {
        val request = AutomationIrRequest.parse("38000", " 9000, 4500\n560 1690,560 ")
        assertEquals(38000, request.frequency)
        assertArrayEquals(intArrayOf(9000, 4500, 560, 1690, 560), request.pattern)
    }

    @Test fun acceptsIntegerArrayIncludingOddStopMark() {
        val pattern = intArrayOf(9000, 4500, 560)
        val request = AutomationIrRequest.parse(38000, pattern)
        pattern[0] = 1
        assertArrayEquals(intArrayOf(9000, 4500, 560), request.pattern)
    }

    @Test fun rejectsMissingInvalidAndOutOfRangeFrequency() {
        listOf(null, 0, -1, 9999, 100001, "38000Hz", 38000.5, 38000L).forEach {
            assertThrows(IllegalArgumentException::class.java) {
                AutomationIrRequest.parse(it, "9000,4500,560")
            }
        }
    }

    @Test fun rejectsMalformedPatternsInsteadOfPartiallyParsing() {
        listOf(null, "", "1,,2", ",1", "1,", "1,-2", "0,1", "1,2.5", "1,abc",
            "0x10,20", "2147483648", intArrayOf(), intArrayOf(1, 0),
            intArrayOf(-1), listOf(560, 560)).forEach {
            assertThrows(IllegalArgumentException::class.java) { AutomationIrRequest.parse(38000, it) }
        }
    }

    @Test fun boundsPayloadSizeAndTotalDurationWithoutIntegerOverflow() {
        listOf("1".repeat(32769), IntArray(4097) { 1 },
            List(4097) { "1" }.joinToString(","), intArrayOf(1000000, 1000000),
            intArrayOf(Int.MAX_VALUE, Int.MAX_VALUE, 100)).forEach {
            assertThrows(IllegalArgumentException::class.java) { AutomationIrRequest.parse(38000, it) }
        }
        assertEquals(4096, AutomationIrRequest.parse(38000, IntArray(4096) { 1 }).pattern.size)
        assertEquals(1999999, AutomationIrRequest.parse(38000, "1999999").pattern.single())
    }
}

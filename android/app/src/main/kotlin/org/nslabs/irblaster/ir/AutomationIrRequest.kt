package org.nslabs.ir_blaster

internal data class AutomationIrRequest(val frequency: Int, val pattern: IntArray) {
    companion object {
        fun parse(frequencyExtra: Any?, patternExtra: Any?): AutomationIrRequest {
            val frequency = when (frequencyExtra) {
                is Int -> frequencyExtra
                is String -> frequencyExtra.trim().toIntOrNull()
                else -> null
            }
            require(frequency != null && frequency in 10000..100000) {
                "frequency must be an integer in Hz between 10000 and 100000"
            }
            val pattern = when (patternExtra) {
                is IntArray -> {
                    require(patternExtra.size in 1..4096) { "pattern must contain 1..4096 durations" }
                    patternExtra.copyOf()
                }
                is String -> {
                    require(patternExtra.length <= 32768) { "pattern text is too large" }
                    val tokens = patternExtra.trim().split(Regex("\\s*,\\s*|\\s+"))
                    require(tokens.size in 1..4096) { "pattern must contain 1..4096 durations" }
                    tokens.map { token ->
                        require(token.isNotEmpty() && token.all { it in '0'..'9' }) {
                            "pattern must contain decimal durations"
                        }
                        requireNotNull(token.toIntOrNull()) { "pattern duration is too large" }
                    }.toIntArray()
                }
                else -> throw IllegalArgumentException("pattern must be text or an integer array")
            }
            require(pattern.all { it > 0 }) { "pattern durations must be positive" }
            // ConsumerIrManager only accepts transmissions shorter than two seconds.
            require(pattern.sumOf { it.toLong() } < 2000000L) { "pattern must be shorter than two seconds" }
            return AutomationIrRequest(frequency, pattern)
        }
    }
}

package org.nslabs.ir_blaster

internal enum class AutomationEmitter { INTERNAL, USB, AUDIO_1_LED, AUDIO_2_LED }

internal data class AutomationIrRequest(
    val frequency: Int,
    val pattern: IntArray,
    val emitter: AutomationEmitter = AutomationEmitter.INTERNAL,
) {
    companion object {
        fun parse(frequencyExtra: Any?, patternExtra: Any?, emitterExtra: Any? = null): AutomationIrRequest {
            val emitter = when (emitterExtra) {
                null -> AutomationEmitter.INTERNAL
                is String -> AutomationEmitter.valueOf(emitterExtra)
                else -> throw IllegalArgumentException("emitter must be a supported emitter name")
            }
            val frequency = when (frequencyExtra) {
                is Int -> frequencyExtra
                is String -> frequencyExtra.trim().toIntOrNull()
                else -> null
            }
            require(frequency != null && frequency in 10000..100000) {
                "frequency must be an integer in Hz between 10000 and 100000"
            }
            if (emitter == AutomationEmitter.AUDIO_1_LED || emitter == AutomationEmitter.AUDIO_2_LED) {
                require(frequency in 15000..60000) { "audio frequency must be between 15000 and 60000 Hz" }
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
            return AutomationIrRequest(frequency, pattern, emitter)
        }
    }
}

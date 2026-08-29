package com.iraq.nireader.data.ocr

/**
 * Calculates and verifies ICAO Doc 9303 check digits using the standard (7, 3, 1) weighting algorithm.
 */
object MrzCheckDigitCalculator {

    private val WEIGHTS = intArrayOf(7, 3, 1)

    /**
     * Converts a single MRZ character to its numeric value according to ICAO 9303.
     * '<' = 0
     * '0'..'9' = 0..9
     * 'A'..'Z' = 10..35
     */
    fun charToValue(c: Char): Int {
        return when (c) {
            in '0'..'9' -> c - '0'
            in 'A'..'Z' -> c - 'A' + 10
            '<' -> 0
            else -> 0
        }
    }

    /**
     * Calculates the check digit character ('0'..'9') for a given MRZ text string.
     */
    fun calculateCheckDigit(text: String): Char {
        var sum = 0
        for (i in text.indices) {
            val charVal = charToValue(text[i].uppercaseChar())
            val weight = WEIGHTS[i % WEIGHTS.size]
            sum += charVal * weight
        }
        val remainder = sum % 10
        return (remainder + '0'.code).toChar()
    }

    /**
     * Validates whether the expected check digit matches the calculated check digit.
     */
    fun verify(text: String, expectedCheckDigit: Char): Boolean {
        if (text.isEmpty()) return false
        val calculated = calculateCheckDigit(text)
        return calculated == expectedCheckDigit
    }
}

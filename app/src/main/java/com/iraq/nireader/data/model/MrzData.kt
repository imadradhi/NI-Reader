package com.iraq.nireader.data.model

import kotlinx.serialization.Serializable

/**
 * Parsed MRZ (Machine Readable Zone) information from the Iraqi ID back side.
 * Complies with ICAO Doc 9303 TD1 standard (3 lines x 30 characters).
 */
@Serializable
data class MrzData(
    val rawMrzLines: List<String>,
    val documentType: String = "I",
    val issuingCountry: String = "IRQ",
    val documentNumber: String,
    val documentNumberCheckDigit: Char,
    val isDocumentNumberValid: Boolean,
    val dateOfBirth: String, // YYMMDD
    val dateOfBirthCheckDigit: Char,
    val isDateOfBirthValid: Boolean,
    val gender: String, // M / F / <
    val expiryDate: String, // YYMMDD
    val expiryDateCheckDigit: Char,
    val isExpiryDateValid: Boolean,
    val nationality: String = "IRQ",
    val optionalData1: String? = null,
    val compositeCheckDigit: Char,
    val isCompositeValid: Boolean,
    val primaryIdentifier: String, // Surname / Family name
    val secondaryIdentifier: String // Given names
) {
    /**
     * Converts to formatted YYYY-MM-DD string for standardized representations.
     */
    fun formattedDob(centuryThreshold: Int = 30): String {
        if (dateOfBirth.length < 6) return dateOfBirth
        val yy = dateOfBirth.substring(0, 2).toIntOrNull() ?: 0
        val mm = dateOfBirth.substring(2, 4)
        val dd = dateOfBirth.substring(4, 6)
        val fullYear = if (yy <= centuryThreshold) "20$yy" else "19$yy"
        return "$fullYear-$mm-$dd"
    }

    fun formattedExpiry(centuryThreshold: Int = 70): String {
        if (expiryDate.length < 6) return expiryDate
        val yy = expiryDate.substring(0, 2).toIntOrNull() ?: 0
        val mm = expiryDate.substring(2, 4)
        val dd = expiryDate.substring(4, 6)
        val fullYear = if (yy <= centuryThreshold) "20$yy" else "19$yy"
        return "$fullYear-$mm-$dd"
    }

    val isOverallMrzValid: Boolean
        get() = isDocumentNumberValid && isDateOfBirthValid && isExpiryDateValid && isCompositeValid
}

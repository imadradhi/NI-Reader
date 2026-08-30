package com.iraq.nireader.data.nfc

import org.jmrtd.BACKey
import org.jmrtd.BACKeySpec

/**
 * Key credentials required for Basic Access Control (BAC) and PACE password authentication.
 */
data class NfcAuthKey(
    val documentNumber: String,
    val dateOfBirth: String, // YYMMDD
    val dateOfExpiry: String  // YYMMDD
) {
    /**
     * Converts to JMRTD BACKeySpec
     */
    fun toBacKeySpec(): BACKeySpec {
        // 1. Clean and normalize document number (9 chars, uppercase, alphanumeric)
        val rawDoc = documentNumber.replace("<", "").replace(" ", "").trim().uppercase()
        val cleanDoc = if (rawDoc.length < 9) rawDoc.padEnd(9, '<') else rawDoc.take(9)

        // 2. Clean date of birth (must be strictly 6 digits: YYMMDD)
        val rawDob = dateOfBirth.replace("-", "").replace("/", "").replace(" ", "").replace("<", "").trim()
        val cleanDob = when {
            rawDob.length == 8 -> rawDob.substring(2, 8) // e.g. 19900101 -> 900101
            rawDob.length >= 6 -> rawDob.substring(0, 6)
            else -> rawDob.padEnd(6, '0')
        }

        // 3. Clean date of expiry (must be strictly 6 digits: YYMMDD)
        val rawExp = dateOfExpiry.replace("-", "").replace("/", "").replace(" ", "").replace("<", "").trim()
        val cleanExp = when {
            rawExp.length == 8 -> rawExp.substring(2, 8) // e.g. 20300101 -> 300101
            rawExp.length >= 6 -> rawExp.substring(0, 6)
            else -> rawExp.padEnd(6, '0')
        }

        return BACKey(cleanDoc, cleanDob, cleanExp)
    }

    companion object {
        fun fromValues(docNum: String, dob: String, expiry: String): NfcAuthKey {
            return NfcAuthKey(
                documentNumber = docNum.trim().uppercase(),
                dateOfBirth = dob.trim(),
                dateOfExpiry = expiry.trim()
            )
        }
    }
}

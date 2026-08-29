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
        // Clean doc number (replace padding characters and whitespace)
        val cleanDoc = documentNumber.replace("<", "").trim()
        val cleanDob = dateOfBirth.replace("<", "").trim()
        val cleanExp = dateOfExpiry.replace("<", "").trim()
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

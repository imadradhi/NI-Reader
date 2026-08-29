package com.iraq.nireader.data.model

import kotlinx.serialization.Serializable

/**
 * Unified model for a single complete Iraqi National ID read operation.
 * Formatted cleanly for transmission to the desktop application over USB / REST API.
 */
@Serializable
data class CardData(
    val timestamp: Long = System.currentTimeMillis(),
    val personalData: PersonalData,
    val mrzData: MrzData? = null,
    val nfcData: NfcData? = null,
    val images: CardImages,
    val verification: VerificationReport
)

@Serializable
data class PersonalData(
    val nationalIdNumber: String,
    val fullNameArabic: String? = null,
    val fullNameEnglish: String? = null,
    val dateOfBirth: String, // Format: YYYY-MM-DD
    val gender: String,      // M or F
    val expiryDate: String,  // Format: YYYY-MM-DD
    val nationality: String = "IRQ",
    val motherName: String? = null,
    val familyNumber: String? = null,
    val registrationNumber: String? = null,
    val province: String? = null,
    val custodyInformation: String? = null
)


@Serializable
data class CardImages(
    val frontImageBase64: String? = null,
    val backImageBase64: String? = null,
    val chipPhotoBase64: String? = null
)

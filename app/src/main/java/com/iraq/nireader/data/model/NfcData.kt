package com.iraq.nireader.data.model

import kotlinx.serialization.Serializable

/**
 * NFC Chip data model extracted from ICAO 9303 Data Groups (DG1, DG2, DG11, DG13, SOD).
 */
@Serializable
data class NfcData(
    val authProtocol: String, // "BAC" or "PACE"
    val isAuthSuccessful: Boolean,
    val dg1Data: Dg1MrzInfo? = null,
    val dg2FacePresent: Boolean = false,
    val dg11Details: Dg11PersonalDetails? = null,
    val dg13Details: Map<String, String>? = null,
    val sodInfo: SodSecurityInfo? = null,
    val readDurationMs: Long = 0
)

@Serializable
data class Dg1MrzInfo(
    val documentType: String,
    val issuingCountry: String,
    val documentNumber: String,
    val dateOfBirth: String,
    val gender: String,
    val expiryDate: String,
    val nationality: String,
    val primaryIdentifier: String,
    val secondaryIdentifier: String
)

@Serializable
data class Dg11PersonalDetails(
    val fullNameNationalLanguage: String? = null, // Arabic full name if present
    val placeOfBirth: String? = null,
    val telephone: String? = null,
    val profession: String? = null,
    val title: String? = null,
    val personalSummary: String? = null,
    val custodyInformation: String? = null
)

@Serializable
data class SodSecurityInfo(
    val digestAlgorithm: String? = null,
    val signatureAlgorithm: String? = null,
    val issuerName: String? = null,
    val serialNumber: String? = null,
    val isSignatureValid: Boolean? = null
)

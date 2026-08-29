package com.iraq.nireader.data.model

import kotlinx.serialization.Serializable

/**
 * Cross-verification verdict comparing OCR extracted printed data with electronic NFC chip data.
 */
@Serializable
data class VerificationReport(
    val ocrStatus: VerificationStatus,
    val nfcStatus: VerificationStatus,
    val matchingStatus: VerificationStatus,
    val overallStatus: VerificationStatus,
    val fieldChecks: List<FieldMatchCheck>,
    val failureReasons: List<String> = emptyList()
)

@Serializable
enum class VerificationStatus {
    PASS,
    FAILED,
    SKIPPED,
    WARNING
}

@Serializable
data class FieldMatchCheck(
    val fieldName: String,
    val ocrValue: String,
    val nfcValue: String,
    val isMatch: Boolean,
    val similarityScore: Float = if (isMatch) 1.0f else 0.0f
)

package com.iraq.nireader.data.model

import kotlinx.serialization.Serializable

/**
 * Standard request payload for POST /api/national-id/read sent to Desktop Host.
 */
@Serializable
data class ApiCardReadRequest(
    val deviceId: String,
    val appVersion: String = "1.0.0",
    val readTimestamp: Long,
    val cardData: CardData
)

/**
 * Expected response from Desktop Server.
 */
@Serializable
data class ApiCardReadResponse(
    val status: ApiResponseStatus,
    val message: String? = null,
    val transactionId: String? = null
)

@Serializable
enum class ApiResponseStatus {
    SUCCESS,
    FAILED,
    INVALID_DATA,
    UNAUTHORIZED,
    SERVER_ERROR
}

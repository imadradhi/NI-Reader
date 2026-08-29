package com.iraq.nireader.data.api

import android.os.Build
import com.iraq.nireader.data.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * REST API client communicating with the desktop host application over USB / Local network.
 */
class DesktopApiClient(
    private var baseUrl: String = "http://192.168.42.129:8080"
) {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = false
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    fun updateBaseUrl(newUrl: String) {
        this.baseUrl = newUrl.trimEnd('/')
    }

    fun getBaseUrl(): String = baseUrl

    /**
     * Checks if Desktop API server is reachable.
     */
    suspend fun checkHealth(): Boolean = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url("$baseUrl/api/health")
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                response.isSuccessful
            }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Sends the complete CardData payload to Desktop API endpoint POST /api/national-id/read.
     */
    suspend fun sendCardData(cardData: CardData): Result<ApiCardReadResponse> = withContext(Dispatchers.IO) {
        try {
            val payload = ApiCardReadRequest(
                deviceId = "${Build.MANUFACTURER} ${Build.MODEL}",
                readTimestamp = System.currentTimeMillis(),
                cardData = cardData
            )

            val jsonBody = json.encodeToString(payload)
            val requestBody = jsonBody.toRequestBody("application/json; charset=utf-8".toMediaType())

            val request = Request.Builder()
                .url("$baseUrl/api/national-id/read")
                .post(requestBody)
                .build()

            client.newCall(request).execute().use { response ->
                val bodyString = response.body?.string().orEmpty()
                if (response.isSuccessful && bodyString.isNotEmpty()) {
                    val apiResponse = try {
                        json.decodeFromString<ApiCardReadResponse>(bodyString)
                    } catch (e: Exception) {
                        ApiCardReadResponse(ApiResponseStatus.SUCCESS, "Received response: $bodyString")
                    }
                    Result.success(apiResponse)
                } else {
                    Result.failure(Exception("Server returned HTTP ${response.code}: $bodyString"))
                }
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

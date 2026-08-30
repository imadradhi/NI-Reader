package com.iraq.nireader.data.nfc

import android.graphics.Bitmap
import com.iraq.nireader.data.model.NfcData

/**
 * State representation for the NFC reading lifecycle.
 */
sealed class NfcReadStatus {
    object Idle : NfcReadStatus()
    
    data class CardDiscovered(
        val historicalBytes: String? = null,
        val protocol: String = "ISO-DEP",
        val message: String = "تم اكتشاف الشريحة ✓ جاري إنشاء قناة اتصال آمنة..."
    ) : NfcReadStatus()

    data class Authenticating(
        val protocol: String = "BAC",
        val message: String = "جاري المصادقة الأمنية وفك التشفير ($protocol)..."
    ) : NfcReadStatus()

    data class ReadingDataGroup(
        val groupName: String,
        val currentStep: Int,
        val totalSteps: Int,
        val progressPercentage: Int,
        val stepDetail: String = ""
    ) : NfcReadStatus()

    data class Success(
        val nfcData: NfcData,
        val chipFaceBitmap: Bitmap?,
        val chipFaceBase64: String?
    ) : NfcReadStatus()

    data class Error(
        val message: String,
        val isAuthFailure: Boolean = false,
        val isCardLost: Boolean = false,
        val failurePhase: String? = null,
        val throwable: Throwable? = null
    ) : NfcReadStatus()
}

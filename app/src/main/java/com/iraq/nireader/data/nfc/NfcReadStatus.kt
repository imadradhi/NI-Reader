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
        val protocol: String = "ISO-DEP"
    ) : NfcReadStatus()

    data class Authenticating(
        val protocol: String = "BAC"
    ) : NfcReadStatus()

    data class ReadingDataGroup(
        val groupName: String,
        val currentStep: Int,
        val totalSteps: Int
    ) : NfcReadStatus()

    data class Success(
        val nfcData: NfcData,
        val chipFaceBitmap: Bitmap?,
        val chipFaceBase64: String?
    ) : NfcReadStatus()

    data class Error(
        val message: String,
        val failurePhase: String? = null,
        val throwable: Throwable? = null
    ) : NfcReadStatus()
}

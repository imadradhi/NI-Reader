package com.iraq.nireader.ui

import android.app.Application
import android.graphics.Bitmap
import android.nfc.Tag
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.iraq.nireader.data.api.DesktopApiClient
import com.iraq.nireader.data.model.*
import com.iraq.nireader.data.nfc.*
import com.iraq.nireader.data.ocr.MrzOcrDetector
import com.iraq.nireader.data.ocr.MrzParser
import com.iraq.nireader.data.usb.UsbConnectionManager
import com.iraq.nireader.data.usb.UsbState
import com.iraq.nireader.data.verification.CrossDataVerifier
import com.iraq.nireader.utils.ImageUtils
import com.iraq.nireader.utils.SecurityZeroizer
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

enum class AppStep {
    IDLE,
    CAMERA_FRONT,
    CAMERA_BACK,
    NFC_TAP,
    VERIFICATION,
    SENDING,
    SUCCESS,
    ERROR
}

data class UiState(
    val currentStep: AppStep = AppStep.IDLE,
    val usbConnected: Boolean = false,
    val apiConnected: Boolean = false,
    val nfcReady: Boolean = false,
    val nfcReadingStatusText: String = "",
    val statusMessage: String = "Ready to scan National ID card",
    val frontBitmap: Bitmap? = null,
    val backBitmap: Bitmap? = null,
    val chipFaceBitmap: Bitmap? = null,
    val mrzData: MrzData? = null,
    val nfcData: NfcData? = null,
    val verificationReport: VerificationReport? = null,
    val cardDataPayload: CardData? = null,
    val errorMessage: String? = null,
    val debugLogs: List<String> = emptyList()
)

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    val usbConnectionManager = UsbConnectionManager(application)
    val desktopApiClient = DesktopApiClient()
    val nfcAdapterManager = NfcAdapterManager(application)
    private val nfcReader = IraqiIdNfcReader()
    private val ocrDetector = MrzOcrDetector()

    // Temporary storage in memory
    private var frontBase64: String? = null
    private var backBase64: String? = null
    private var chipFaceBase64: String? = null

    init {
        usbConnectionManager.startListening()
        observeUsbState()
        checkNfcAvailability()
        checkApiHealth()
    }

    private fun observeUsbState() {
        viewModelScope.launch {
            usbConnectionManager.usbState.collect { state ->
                val connected = (state == UsbState.CONNECTED)
                _uiState.update { it.copy(usbConnected = connected) }
                addDebugLog("USB State Changed: $state")
                if (connected) {
                    checkApiHealth()
                }
            }
        }
    }

    fun checkNfcAvailability() {
        val supported = nfcAdapterManager.isNfcSupported
        val enabled = nfcAdapterManager.isNfcEnabled
        _uiState.update { it.copy(nfcReady = supported && enabled) }
        addDebugLog("NFC check: supported=$supported, enabled=$enabled")
    }

    fun checkApiHealth() {
        viewModelScope.launch {
            val isHealthy = desktopApiClient.checkHealth()
            _uiState.update { it.copy(apiConnected = isHealthy) }
            addDebugLog("API Health check: isHealthy=$isHealthy (Host: ${desktopApiClient.getBaseUrl()})")
        }
    }

    fun setApiUrl(url: String) {
        desktopApiClient.updateBaseUrl(url)
        checkApiHealth()
    }

    fun startReadingFlow() {
        _uiState.update {
            it.copy(
                currentStep = AppStep.CAMERA_FRONT,
                statusMessage = "Step 1: Capture front side photo",
                errorMessage = null
            )
        }
        addDebugLog("Started reading flow: Step 1 FRONT")
    }

    fun skipToNfcDirect(docNum: String, dob: String, expiry: String) {
        // Direct testing flow (Phase 1 testing without camera)
        val mrz = MrzData(
            rawMrzLines = listOf("I<IRQ$docNum", "$dob<$expiry<IRQ", "CARDHOLDER<<TEST"),
            documentNumber = docNum,
            documentNumberCheckDigit = '0',
            isDocumentNumberValid = true,
            dateOfBirth = dob,
            dateOfBirthCheckDigit = '0',
            isDateOfBirthValid = true,
            gender = "M",
            expiryDate = expiry,
            expiryDateCheckDigit = '0',
            isExpiryDateValid = true,
            compositeCheckDigit = '0',
            isCompositeValid = true,
            primaryIdentifier = "CARDHOLDER",
            secondaryIdentifier = "TEST"
        )
        _uiState.update {
            it.copy(
                mrzData = mrz,
                currentStep = AppStep.NFC_TAP,
                statusMessage = "Hold card near the NFC sensor on phone back"
            )
        }
        addDebugLog("Manual BAC key configured. Ready for NFC Tap: Doc=$docNum, DOB=$dob, Exp=$expiry")
    }

    fun onFrontImageCaptured(bitmap: Bitmap) {
        frontBase64 = ImageUtils.bitmapToBase64(bitmap)
        _uiState.update {
            it.copy(
                frontBitmap = bitmap,
                currentStep = AppStep.CAMERA_BACK,
                statusMessage = "Step 2: Point camera at back side (MRZ)"
            )
        }
        addDebugLog("Front image captured successfully")
    }

    fun onBackImageCaptured(bitmap: Bitmap) {
        backBase64 = ImageUtils.bitmapToBase64(bitmap)
        _uiState.update {
            it.copy(
                backBitmap = bitmap,
                statusMessage = "Reading and analyzing MRZ with OCR..."
            )
        }
        addDebugLog("Back image captured. Processing OCR...")

        viewModelScope.launch {
            val result = ocrDetector.detectMrz(bitmap)
            result.onSuccess { mrz ->
                addDebugLog("MRZ detected successfully: Doc=${mrz.documentNumber}, DOB=${mrz.dateOfBirth}, Exp=${mrz.expiryDate}")
                _uiState.update {
                    it.copy(
                        mrzData = mrz,
                        currentStep = AppStep.NFC_TAP,
                        statusMessage = "Step 3: Hold card near the NFC sensor on phone back"
                    )
                }
            }.onFailure { error ->
                addDebugLog("MRZ OCR Failed: ${error.message}")
                _uiState.update {
                    it.copy(
                        statusMessage = "Unable to read MRZ automatically. Retake photo or enter keys manually.",
                        errorMessage = "MRZ OCR Error: ${error.message}"
                    )
                }
            }
        }
    }

    fun onNfcTagDiscovered(tag: Tag) {
        val currentStep = _uiState.value.currentStep
        if (currentStep != AppStep.NFC_TAP && currentStep != AppStep.IDLE) return

        val mrz = _uiState.value.mrzData
        if (mrz == null) {
            _uiState.update {
                it.copy(
                    errorMessage = "Please scan MRZ or enter BAC keys before NFC reading",
                    statusMessage = "BAC keys unavailable"
                )
            }
            return
        }

        val authKey = MrzParser.extractNfcAuthKey(mrz)
        addDebugLog("NFC Tag Discovered. Initiating reading with BAC Key: ${authKey.documentNumber}")

        viewModelScope.launch {
            nfcReader.readCard(tag, authKey).collect { status ->
                when (status) {
                    is NfcReadStatus.CardDiscovered -> {
                        _uiState.update { it.copy(nfcReadingStatusText = "Card discovered (${status.historicalBytes ?: "ISO-DEP"})") }
                        addDebugLog("NFC Tag connected: ${status.historicalBytes}")
                    }
                    is NfcReadStatus.Authenticating -> {
                        _uiState.update { it.copy(nfcReadingStatusText = "Authenticating session (${status.protocol})...") }
                        addDebugLog("Authenticating via ${status.protocol}")
                    }
                    is NfcReadStatus.ReadingDataGroup -> {
                        _uiState.update {
                            it.copy(
                                nfcReadingStatusText = "Reading ${status.groupName} (${status.currentStep}/${status.totalSteps})..."
                            )
                        }
                        addDebugLog("Reading ${status.groupName}")
                    }
                    is NfcReadStatus.Success -> {
                        chipFaceBase64 = status.chipFaceBase64
                        addDebugLog("NFC Read Successful! Protocol=${status.nfcData.authProtocol}, Duration=${status.nfcData.readDurationMs}ms")
                        processCompleteRead(status.nfcData, status.chipFaceBitmap)
                    }
                    is NfcReadStatus.Error -> {
                        addDebugLog("NFC Read Failed: ${status.message}")
                        _uiState.update {
                            it.copy(
                                currentStep = AppStep.NFC_TAP,
                                nfcReadingStatusText = "",
                                errorMessage = "NFC Read Failed: ${status.message}",
                                statusMessage = "Connection failed with chip. Hold card steady and re-tap."
                            )
                        }
                    }
                    else -> Unit
                }
            }
        }
    }

    private fun processCompleteRead(nfcData: NfcData, chipFaceBmp: Bitmap?) {
        val mrz = _uiState.value.mrzData
        val verification = CrossDataVerifier.verify(mrz, nfcData)
        addDebugLog("Verification completed: OverallStatus=${verification.overallStatus}")

        val dg1 = nfcData.dg1Data
        val dg11 = nfcData.dg11Details
        val personalData = PersonalData(
            nationalIdNumber = dg1?.documentNumber ?: mrz?.documentNumber ?: "",
            fullNameArabic = dg11?.fullNameNationalLanguage,
            fullNameEnglish = "${dg1?.primaryIdentifier.orEmpty()} ${dg1?.secondaryIdentifier.orEmpty()}".trim(),
            dateOfBirth = mrz?.formattedDob() ?: dg1?.dateOfBirth ?: "",
            gender = dg1?.gender ?: mrz?.gender ?: "M",
            expiryDate = mrz?.formattedExpiry() ?: dg1?.expiryDate ?: "",
            nationality = dg1?.nationality ?: "IRQ",
            province = dg11?.placeOfBirth,
            custodyInformation = dg11?.custodyInformation
        )

        val cardImages = CardImages(
            frontImageBase64 = frontBase64,
            backImageBase64 = backBase64,
            chipPhotoBase64 = chipFaceBase64
        )

        val cardPayload = CardData(
            personalData = personalData,
            mrzData = mrz,
            nfcData = nfcData,
            images = cardImages,
            verification = verification
        )

        _uiState.update {
            it.copy(
                currentStep = AppStep.VERIFICATION,
                chipFaceBitmap = chipFaceBmp,
                nfcData = nfcData,
                verificationReport = verification,
                cardDataPayload = cardPayload,
                statusMessage = "Card data verified successfully ✓"
            )
        }
    }

    fun sendDataToDesktop() {
        val payload = _uiState.value.cardDataPayload ?: return
        _uiState.update {
            it.copy(
                currentStep = AppStep.SENDING,
                statusMessage = "Sending data to desktop application via USB / API..."
            )
        }
        addDebugLog("Sending CardData payload to Desktop API...")

        viewModelScope.launch {
            val result = desktopApiClient.sendCardData(payload)
            result.onSuccess { response ->
                addDebugLog("API Response received: status=${response.status}, msg=${response.message}")
                if (response.status == ApiResponseStatus.SUCCESS) {
                    _uiState.update {
                        it.copy(
                            currentStep = AppStep.SUCCESS,
                            statusMessage = "Card data successfully transmitted to desktop PC ✓"
                        )
                    }
                } else {
                    _uiState.update {
                        it.copy(
                            currentStep = AppStep.VERIFICATION,
                            errorMessage = "Server error: ${response.message ?: response.status.name}",
                            statusMessage = "Desktop server rejected the payload"
                        )
                    }
                }
            }.onFailure { error ->
                addDebugLog("API Send Failed: ${error.message}")
                _uiState.update {
                    it.copy(
                        currentStep = AppStep.VERIFICATION,
                        errorMessage = "Send failed: ${error.message}. Ensure USB is tethered and server is running.",
                        statusMessage = "Failed to transmit data to PC"
                    )
                }
            }
        }
    }

    fun resetCardData() {
        // Zeroize memory buffers per security requirement
        SecurityZeroizer.wipeBitmap(_uiState.value.frontBitmap)
        SecurityZeroizer.wipeBitmap(_uiState.value.backBitmap)
        SecurityZeroizer.wipeBitmap(_uiState.value.chipFaceBitmap)
        frontBase64 = null
        backBase64 = null
        chipFaceBase64 = null
        SecurityZeroizer.requestMemoryPurge()

        _uiState.update {
            UiState(
                usbConnected = it.usbConnected,
                apiConnected = it.apiConnected,
                nfcReady = it.nfcReady,
                currentStep = AppStep.IDLE,
                statusMessage = "Ready to scan National ID card",
                debugLogs = it.debugLogs
            )
        }
        addDebugLog("Memory sanitized & reset completed. Ready for next card.")
    }

    private fun addDebugLog(message: String) {
        val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
        val log = "[$timestamp] $message"
        _uiState.update {
            val updated = it.debugLogs.takeLast(50).toMutableList()
            updated.add(log)
            it.copy(debugLogs = updated)
        }
    }

    override fun onCleared() {
        super.onCleared()
        usbConnectionManager.stopListening()
        ocrDetector.close()
        resetCardData()
    }
}

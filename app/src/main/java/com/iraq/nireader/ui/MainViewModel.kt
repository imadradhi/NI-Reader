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
    MRZ_CONFIRMATION,
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
    val nfcStage: Int = 0, // 0 = Waiting, 1 = Detected, 2 = Communicating/Auth, 3 = Reading, 4 = Complete
    val nfcReadingStatusText: String = "",
    val nfcProgressPercentage: Int = 0,
    val nfcStepDetail: String = "",
    val isNfcChipConnected: Boolean = false,
    val statusMessage: String = "جاهز لقراءة البطاقة الوطنية العراقية",
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
        addDebugLog("App running in standalone offline mode.")
    }

    private fun observeUsbState() {
        viewModelScope.launch {
            usbConnectionManager.usbState.collect { state ->
                val connected = (state == UsbState.CONNECTED)
                _uiState.update { it.copy(usbConnected = connected) }
                addDebugLog("USB State Changed: $state")
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
        // Disabled per user requirement (100% standalone offline mode)
    }

    fun setApiUrl(url: String) {
        // Disabled per user requirement
    }

    fun startReadingFlow() {
        _uiState.update {
            it.copy(
                currentStep = AppStep.CAMERA_BACK,
                statusMessage = "وجه الكاميرا نحو خلفية البطاقة (منطقة الـ MRZ)",
                errorMessage = null
            )
        }
        addDebugLog("Started reading flow: Point camera at back MRZ")
    }

    fun cancelScanning() {
        _uiState.update {
            it.copy(
                currentStep = AppStep.IDLE,
                statusMessage = "جاهز لقراءة البطاقة الوطنية العراقية",
                errorMessage = null,
                isNfcChipConnected = false,
                nfcProgressPercentage = 0,
                nfcStepDetail = ""
            )
        }
        addDebugLog("Scanning cancelled by user. Returned to IDLE.")
    }

    fun proceedToNfc() {
        _uiState.update {
            it.copy(
                currentStep = AppStep.NFC_TAP,
                isNfcChipConnected = false,
                nfcStage = 0,
                nfcProgressPercentage = 0,
                nfcStepDetail = "ضع ظهر البطاقة ملامساً لحساس الـ NFC خلف الهاتف",
                statusMessage = "ضع البطاقة خلف الهاتف لقراءة الشريحة الإلكترونية"
            )
        }
        addDebugLog("Proceeding from MRZ Confirmation to NFC Tap.")
    }

    fun rescanMrz() {
        _uiState.update {
            it.copy(
                currentStep = AppStep.CAMERA_BACK,
                mrzData = null,
                nfcStage = 0,
                statusMessage = "أعد توجيه الكاميرا نحو الـ MRZ في ظهر البطاقة",
                errorMessage = null
            )
        }
        addDebugLog("Rescan MRZ requested by user.")
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
                isNfcChipConnected = false,
                nfcStage = 0,
                nfcProgressPercentage = 0,
                nfcStepDetail = "ضع ظهر البطاقة ملامساً لحساس الـ NFC",
                statusMessage = "ضع البطاقة بالقرب من حساس الـ NFC خلف الهاتف"
            )
        }
        addDebugLog("Manual BAC key configured. Ready for NFC Tap: Doc=$docNum, DOB=$dob, Exp=$expiry")
    }

    fun onMrzExtractedDirectly(mrz: MrzData) {
        addDebugLog("Direct Live MRZ detected: Doc=${mrz.documentNumber}, DOB=${mrz.dateOfBirth}, Exp=${mrz.expiryDate}")
        _uiState.update {
            it.copy(
                mrzData = mrz,
                currentStep = AppStep.MRZ_CONFIRMATION,
                statusMessage = "تمت قراءة وتدقيق الـ MRZ بنجاح ✓"
            )
        }
    }

    fun onFrontImageCaptured(bitmap: Bitmap) {
        frontBase64 = ImageUtils.bitmapToBase64(bitmap)
        _uiState.update {
            it.copy(
                frontBitmap = bitmap,
                currentStep = AppStep.CAMERA_BACK,
                statusMessage = "الخطوة 2: وجه الكاميرا نحو ظهر البطاقة (منطقة الـ MRZ)"
            )
        }
        addDebugLog("Front image captured successfully")
    }

    fun onBackImageCaptured(bitmap: Bitmap) {
        backBase64 = ImageUtils.bitmapToBase64(bitmap)
        _uiState.update {
            it.copy(
                backBitmap = bitmap,
                statusMessage = "جاري قراءة وتدقيق أرقام الـ MRZ..."
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
                        currentStep = AppStep.MRZ_CONFIRMATION,
                        statusMessage = "تمت قراءة وتدقيق الـ MRZ بنجاح ✓"
                    )
                }
            }.onFailure { error ->
                addDebugLog("MRZ OCR Failed: ${error.message}")
                _uiState.update {
                    it.copy(
                        statusMessage = "تعذر قراءة الـ MRZ بوضوح. يرجى توجيه الكاميرا بإضاءة جيدة أو استخدام الإدخال اليدوي.",
                        errorMessage = "تعذر استخراج بيانات الـ MRZ: ${error.message}"
                    )
                }
            }
        }
    }

    fun onNfcTagDiscovered(tag: Tag) {
        val currentStep = _uiState.value.currentStep
        // Strictly only accept NFC reads when explicitly on the NFC_TAP step
        if (currentStep != AppStep.NFC_TAP) {
            addDebugLog("NFC tag tapped outside of NFC step (Current: $currentStep). Ignoring.")
            return
        }

        val mrz = _uiState.value.mrzData
        if (mrz == null) {
            _uiState.update {
                it.copy(
                    errorMessage = "يرجى مسح الـ MRZ أولاً للتأكد من البيانات قبل قراءة الـ NFC",
                    statusMessage = "مفاتيح المصادقة غير متوفرة"
                )
            }
            return
        }

        val authKey = MrzParser.extractNfcAuthKey(mrz)
        addDebugLog("NFC Tag Discovered. Initiating reading with BAC Key: Doc=${authKey.documentNumber}, DOB=${authKey.dateOfBirth}, Exp=${authKey.dateOfExpiry}")

        viewModelScope.launch {
            nfcReader.readCard(tag, authKey).collect { status ->
                when (status) {
                    is NfcReadStatus.CardDiscovered -> {
                        _uiState.update {
                            it.copy(
                                isNfcChipConnected = true,
                                nfcStage = 1,
                                nfcProgressPercentage = 10,
                                nfcStepDetail = status.message,
                                nfcReadingStatusText = "المرحلة الأولى: تم الكشف عن شريحة NFC بنجاح ✓"
                            )
                        }
                        addDebugLog("NFC Tag connected: ${status.historicalBytes}")
                    }
                    is NfcReadStatus.Authenticating -> {
                        _uiState.update {
                            it.copy(
                                isNfcChipConnected = true,
                                nfcStage = 2,
                                nfcProgressPercentage = 25,
                                nfcStepDetail = status.message,
                                nfcReadingStatusText = "المرحلة الثانية: يتم التواصل وتأكيد المصادقة الأمنية (${status.protocol})..."
                            )
                        }
                        addDebugLog("Authenticating via ${status.protocol}")
                    }
                    is NfcReadStatus.ReadingDataGroup -> {
                        _uiState.update {
                            it.copy(
                                isNfcChipConnected = true,
                                nfcStage = 3,
                                nfcProgressPercentage = status.progressPercentage,
                                nfcStepDetail = status.stepDetail,
                                nfcReadingStatusText = "المرحلة الثالثة: جاري قراءة ${status.groupName} (${status.currentStep}/${status.totalSteps})..."
                            )
                        }
                        addDebugLog("Reading ${status.groupName} (${status.progressPercentage}%)")
                    }
                    is NfcReadStatus.Success -> {
                        chipFaceBase64 = status.chipFaceBase64
                        addDebugLog("NFC Read Successful! Protocol=${status.nfcData.authProtocol}, Duration=${status.nfcData.readDurationMs}ms")
                        _uiState.update {
                            it.copy(
                                isNfcChipConnected = true,
                                nfcStage = 4,
                                nfcProgressPercentage = 100,
                                nfcStepDetail = "اكتملت قراءة الشريحة بنجاح 100% ✓"
                            )
                        }
                        processCompleteRead(status.nfcData, status.chipFaceBitmap)
                    }
                    is NfcReadStatus.Error -> {
                        addDebugLog("NFC Read Failed: ${status.message}")
                        _uiState.update {
                            it.copy(
                                isNfcChipConnected = false,
                                nfcStage = 0,
                                nfcProgressPercentage = 0,
                                nfcReadingStatusText = "",
                                nfcStepDetail = status.message,
                                errorMessage = status.message,
                                statusMessage = if (status.isCardLost) "انقطع الاتصال بالشريحة. أعد تثبيت البطاقة." else "فشل الاتصال بالشريحة."
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
        val docNum = dg1?.documentNumber?.ifEmpty { null } ?: mrz?.documentNumber.orEmpty()
        val arabicName = dg11?.fullNameNationalLanguage
        val englishName = when {
            dg1 != null && (dg1.primaryIdentifier.isNotEmpty() || dg1.secondaryIdentifier.isNotEmpty()) ->
                "${dg1.primaryIdentifier} ${dg1.secondaryIdentifier}".trim()
            mrz != null && (mrz.primaryIdentifier.isNotEmpty() || mrz.secondaryIdentifier.isNotEmpty()) ->
                "${mrz.primaryIdentifier} ${mrz.secondaryIdentifier}".trim()
            else -> null
        }
        val dob = mrz?.formattedDob() ?: dg1?.dateOfBirth.orEmpty()
        val gender = dg1?.gender ?: mrz?.gender ?: "M"
        val expiry = mrz?.formattedExpiry() ?: dg1?.expiryDate.orEmpty()
        val nationality = dg1?.nationality ?: mrz?.nationality ?: "IRQ"
        val nationalNumber = mrz?.optionalData1 ?: dg11?.personalSummary

        val personalData = PersonalData(
            nationalIdNumber = docNum,
            fullNameArabic = arabicName,
            fullNameEnglish = englishName,
            dateOfBirth = dob,
            gender = gender,
            expiryDate = expiry,
            nationality = nationality,
            motherName = null,
            familyNumber = null,
            registrationNumber = nationalNumber,
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
                statusMessage = "تمت قراءة شريحة البطاقة ومطابقة البيانات بنجاح ✓"
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

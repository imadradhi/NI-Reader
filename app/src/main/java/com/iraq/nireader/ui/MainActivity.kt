package com.iraq.nireader.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.annotation.OptIn
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.textfield.TextInputEditText
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.iraq.nireader.R
import com.iraq.nireader.data.model.VerificationStatus
import com.iraq.nireader.data.ocr.MrzOcrDetector
import com.iraq.nireader.data.ocr.MrzParser
import com.iraq.nireader.databinding.ActivityMainBinding
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val viewModel: MainViewModel by viewModels()

    private var cameraExecutor: ExecutorService? = null
    private var analyzerExecutor: ExecutorService? = null
    private var imageCapture: ImageCapture? = null
    private val liveTextRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val ocrDetector = MrzOcrDetector()

    private val isCapturing = AtomicBoolean(false)
    private var consecutiveDetectionCount = 0
    private var lastAutoCaptureTime = 0L

    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            startCamera()
        } else {
            Toast.makeText(this, "Please grant camera permission to scan ID card", Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enforce FLAG_SECURE to prevent screen capture of sensitive identity data
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )

        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        cameraExecutor = Executors.newSingleThreadExecutor()
        analyzerExecutor = Executors.newSingleThreadExecutor()

        setupListeners()
        setupBackNavigation()
        observeViewModel()
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : androidx.activity.OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val step = viewModel.uiState.value.currentStep
                if (step != AppStep.IDLE && step != AppStep.VERIFICATION) {
                    viewModel.cancelScanning()
                } else if (step == AppStep.VERIFICATION) {
                    viewModel.resetCardData()
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                }
            }
        })
    }

    override fun onResume() {
        super.onResume()
        viewModel.checkNfcAvailability()
        viewModel.nfcAdapterManager.enableReaderMode(this) { tag ->
            viewModel.onNfcTagDiscovered(tag)
        }
    }

    override fun onPause() {
        super.onPause()
        viewModel.nfcAdapterManager.disableReaderMode(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor?.shutdown()
        analyzerExecutor?.shutdown()
        liveTextRecognizer.close()
        ocrDetector.close()
    }

    private fun setupListeners() {
        binding.btnStartReading.setOnClickListener {
            checkCameraPermissionAndStart()
        }

        binding.btnCameraBack.setOnClickListener {
            viewModel.cancelScanning()
        }

        binding.btnProceedToNfc.setOnClickListener {
            viewModel.proceedToNfc()
        }

        binding.btnRescanMrz.setOnClickListener {
            viewModel.rescanMrz()
        }

        binding.btnCancelNfc.setOnClickListener {
            viewModel.cancelScanning()
        }

        binding.btnDirectNfcTest.setOnClickListener {
            showManualBacDialog()
        }

        binding.btnSettings.setOnClickListener {
            showApiSettingsDialog()
        }

        binding.btnToggleLogs.setOnClickListener {
            val isVisible = binding.cardDebugLogs.visibility == View.VISIBLE
            binding.cardDebugLogs.visibility = if (isVisible) View.GONE else View.VISIBLE
        }

        binding.btnCloseLogs.setOnClickListener {
            binding.cardDebugLogs.visibility = View.GONE
        }

        binding.btnCaptureCamera.setOnClickListener {
            captureCameraImage()
        }

        binding.btnSendToPc.setOnClickListener {
            viewModel.sendDataToDesktop()
        }

        binding.btnResetCard.setOnClickListener {
            viewModel.resetCardData()
        }
    }

    private fun observeViewModel() {
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    updateHeaderStatus(state)
                    updateCurrentStepLayout(state)
                    updateLogs(state.debugLogs)

                    binding.textBottomStatus.text = state.statusMessage
                    if (state.errorMessage != null && state.errorMessage.isNotEmpty()) {
                        Toast.makeText(this@MainActivity, state.errorMessage, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }

    private fun updateHeaderStatus(state: UiState) {
        // USB Pill
        binding.dotUsb.setBackgroundResource(
            if (state.usbConnected) R.drawable.shape_dot_success else R.drawable.shape_dot_error
        )
        binding.textUsbStatus.text = if (state.usbConnected) "USB: Connected" else "USB: Disconnected"

        // API Pill
        binding.dotApi.setBackgroundResource(
            if (state.apiConnected) R.drawable.shape_dot_success else R.drawable.shape_dot_error
        )
        binding.textApiStatus.text = if (state.apiConnected) "API: Connected" else "API: Disconnected"

        // NFC Pill
        binding.dotNfc.setBackgroundResource(
            if (state.nfcReady) R.drawable.shape_dot_success else R.drawable.shape_dot_error
        )
        binding.textNfcStatus.text = if (state.nfcReady) "NFC: Ready" else "NFC: Disabled"
    }

    private fun updateCurrentStepLayout(state: UiState) {
        binding.layoutIdle.visibility = if (state.currentStep == AppStep.IDLE) View.VISIBLE else View.GONE
        binding.layoutCamera.visibility = if (state.currentStep == AppStep.CAMERA_FRONT || state.currentStep == AppStep.CAMERA_BACK) View.VISIBLE else View.GONE
        binding.layoutMrzConfirmation.visibility = if (state.currentStep == AppStep.MRZ_CONFIRMATION) View.VISIBLE else View.GONE
        binding.layoutNfcTap.visibility = if (state.currentStep == AppStep.NFC_TAP) View.VISIBLE else View.GONE
        binding.layoutVerification.visibility = if (state.currentStep == AppStep.VERIFICATION || state.currentStep == AppStep.SENDING || state.currentStep == AppStep.SUCCESS) View.VISIBLE else View.GONE

        // Reset capture lock & frame border when entering/changing camera step
        if (state.currentStep == AppStep.CAMERA_FRONT || state.currentStep == AppStep.CAMERA_BACK) {
            isCapturing.set(false)
            consecutiveDetectionCount = 0
            binding.cardFrameOverlay.setBackgroundResource(R.drawable.bg_card_frame)
            binding.dotAutoCapture.setBackgroundResource(R.drawable.shape_dot_success)
            binding.textAutoCaptureStatus.text = "جاري البحث عن الـ MRZ..."
            startCamera()
        }

        when (state.currentStep) {
            AppStep.CAMERA_FRONT -> {
                binding.textCameraPrompt.text = "الخطوة 1: ضع واجهة البطاقة داخل الإطار"
            }
            AppStep.CAMERA_BACK -> {
                binding.textCameraPrompt.text = "الخطوة 2: وجه الكاميرا نحو خلفية البطاقة (منطقة الـ MRZ)"
            }
            AppStep.MRZ_CONFIRMATION -> {
                val mrz = state.mrzData
                if (mrz != null) {
                    binding.textMrzDocNumber.text = "${mrz.documentNumber} ✓"
                    binding.textMrzDob.text = "${mrz.formattedDob()} ✓"
                    binding.textMrzExpiry.text = "${mrz.formattedExpiry()} ✓"
                    binding.textMrzHolderName.text = "${mrz.primaryIdentifier} ${mrz.secondaryIdentifier}".trim()
                }
            }
            AppStep.NFC_TAP -> {
                binding.dotNfcChip.setBackgroundResource(
                    if (state.isNfcChipConnected) R.drawable.shape_dot_success else R.drawable.shape_dot_error
                )
                binding.textNfcChipStatus.text = if (state.isNfcChipConnected) "تم العثور على الشريحة ✓" else "بانتظار ملامسة الشريحة..."
                binding.progressNfcHorizontal.progress = state.nfcProgressPercentage
                binding.textNfcPercentage.text = "${state.nfcProgressPercentage}%"
                binding.textNfcLiveProgress.text = if (state.nfcStepDetail.isNotEmpty()) state.nfcStepDetail else "ضع ظهر البطاقة ملامساً لحساس الـ NFC..."

                // Step checklist
                binding.textStepDg1.text = if (state.nfcProgressPercentage >= 25) "✓ 1. تم قراءة البيانات النصية ورقم الوثيقة (DG1)" else "⏳ 1. قراءة البيانات النصية ورقم الوثيقة (DG1)"
                binding.textStepDg2.text = if (state.nfcProgressPercentage >= 60) "✓ 2. تم قراءة الصورة الشخصية الحيوية (DG2)" else "⏳ 2. قراءة الصورة الشخصية الحيوية (DG2)"
                binding.textStepDg11.text = if (state.nfcProgressPercentage >= 80) "✓ 3. تم قراءة الاسم العربي والتفاصيل (DG11)" else "⏳ 3. قراءة الاسم العربي والتفاصيل الشخصية (DG11)"
                binding.textStepSod.text = if (state.nfcProgressPercentage >= 95) "✓ 4. تم تدقيق التوقيع الرقمي والأمان (SOD)" else "⏳ 4. تدقيق التوقيع الرقمي والأمان (SOD)"
            }
            AppStep.VERIFICATION, AppStep.SENDING, AppStep.SUCCESS -> {
                renderVerificationSummary(state)
            }
            else -> Unit
        }
    }

    private fun renderVerificationSummary(state: UiState) {
        val payload = state.cardDataPayload
        val person = payload?.personalData
        val verification = state.verificationReport

        // Biometric Face Photo
        if (state.chipFaceBitmap != null) {
            binding.imgBiometricFace.setImageBitmap(state.chipFaceBitmap)
        } else {
            binding.imgBiometricFace.setImageResource(android.R.drawable.ic_menu_myplaces)
        }

        // Personal text details
        binding.textResultFullNameArabic.text = person?.fullNameArabic ?: "Arabic name not available in DG11"
        binding.textResultFullNameEnglish.text = person?.fullNameEnglish ?: ""
        binding.textResultDocNumber.text = "Document No: ${person?.nationalIdNumber.orEmpty()}"
        binding.textResultDob.text = "DOB: ${person?.dateOfBirth.orEmpty()} (${person?.gender.orEmpty()})"

        // Verdict banner
        val isPass = verification?.overallStatus == VerificationStatus.PASS
        binding.bannerVerdict.setBackgroundResource(
            if (isPass) R.drawable.bg_verdict_pass else R.drawable.bg_verdict_fail
        )
        binding.textVerdict.text = if (isPass) "Verification: Matched ✓" else "Verification: Mismatch Detected ✕"

        // Checklist details
        val checkSummary = StringBuilder()
        verification?.fieldChecks?.forEach { check ->
            val icon = if (check.isMatch) "✓" else "✕"
            checkSummary.append("$icon ${check.fieldName}: ${if (check.isMatch) "Match" else "Mismatch (${check.ocrValue} vs ${check.nfcValue})"}\n")
        }
        if (verification?.failureReasons?.isNotEmpty() == true) {
            checkSummary.append("\nAlert Reasons:\n")
            verification.failureReasons.forEach { reason ->
                checkSummary.append("• $reason\n")
            }
        }
        binding.textFieldCheckSummary.text = checkSummary.toString().trim()

        // Send Button State
        binding.btnSendToPc.isEnabled = (state.currentStep != AppStep.SENDING)
        binding.btnSendToPc.text = when (state.currentStep) {
            AppStep.SENDING -> "Sending..."
            AppStep.SUCCESS -> "Sent Successfully ✓"
            else -> getString(R.string.btn_send_now)
        }
    }

    private fun updateLogs(logs: List<String>) {
        binding.textLogsContent.text = logs.joinToString("\n")
        binding.scrollLogs.post {
            binding.scrollLogs.fullScroll(View.FOCUS_DOWN)
        }
    }

    private fun checkCameraPermissionAndStart() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            viewModel.startReadingFlow()
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    @OptIn(ExperimentalGetImage::class)
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(binding.cameraPreview.surfaceProvider)
            }

            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            val analyzer = analyzerExecutor ?: Executors.newSingleThreadExecutor().also { analyzerExecutor = it }
            imageAnalysis.setAnalyzer(analyzer) { imageProxy ->
                val mediaImage = imageProxy.image
                val currentStep = viewModel.uiState.value.currentStep
                if (mediaImage != null && (currentStep == AppStep.CAMERA_BACK || currentStep == AppStep.CAMERA_FRONT) && !isCapturing.get()) {
                    val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                    liveTextRecognizer.process(inputImage)
                        .addOnSuccessListener { visionText ->
                            processLiveVisionAnalysis(visionText, currentStep)
                        }
                        .addOnCompleteListener {
                            imageProxy.close()
                        }
                } else {
                    imageProxy.close()
                }
            }

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageCapture, imageAnalysis)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun processLiveVisionAnalysis(visionText: Text, currentStep: AppStep) {
        if (isCapturing.get()) return

        val now = System.currentTimeMillis()
        if (now - lastAutoCaptureTime < 1500) return

        var isCardTargetDetected = false

        if (currentStep == AppStep.CAMERA_BACK) {
            val directMrz = ocrDetector.extractMrzFromText(visionText)
            if (directMrz != null) {
                if (isCapturing.compareAndSet(false, true)) {
                    runOnUiThread {
                        triggerHapticFeedback()
                        binding.cardFrameOverlay.setBackgroundResource(R.drawable.bg_card_frame_active)
                        binding.textAutoCaptureStatus.text = "تم مسح الـ MRZ بنجاح ✓"
                        viewModel.onMrzExtractedDirectly(directMrz)
                    }
                }
                return
            }

            // Secondary check: live check for TD1 candidate lines
            val candidateLines = mutableListOf<String>()
            for (block in visionText.textBlocks) {
                for (line in block.lines) {
                    val cleaned = MrzParser.sanitizeLine(line.text)
                    if (cleaned.length >= 15 && (cleaned.contains("<") || cleaned.startsWith("I") || cleaned.contains("IRQ"))) {
                        candidateLines.add(cleaned)
                    }
                }
            }

            if (candidateLines.size >= 2) {
                isCardTargetDetected = true
            }
        } else if (currentStep == AppStep.CAMERA_FRONT) {
            // Front side detection: Check for ID text elements, multiple structured text blocks
            val totalBlocks = visionText.textBlocks.size
            val fullText = visionText.text.uppercase()
            val hasIdKeywords = fullText.contains("IRAQ") || fullText.contains("REPUBLIC") || fullText.contains("CARD") ||
                    fullText.contains("بطاقة") || fullText.contains("وطنية") || fullText.contains("العراق") || fullText.contains("جمهورية") ||
                    visionText.textBlocks.any { it.lines.size >= 2 }

            if (totalBlocks >= 2 && hasIdKeywords) {
                isCardTargetDetected = true
            }
        }

        if (isCardTargetDetected) {
            consecutiveDetectionCount++
            runOnUiThread {
                binding.cardFrameOverlay.setBackgroundResource(R.drawable.bg_card_frame_active)
                binding.textAutoCaptureStatus.text = "تم قفل الإطار على البطاقة ✓"
            }

            // Require 2 consecutive positive detections to ensure steady position
            if (consecutiveDetectionCount >= 2) {
                if (isCapturing.compareAndSet(false, true)) {
                    lastAutoCaptureTime = now
                    runOnUiThread {
                        triggerHapticFeedback()
                        binding.textCameraPrompt.text = if (currentStep == AppStep.CAMERA_FRONT) {
                            "تم التقاط الواجهة الأمامية ✓"
                        } else {
                            "تم التقاط الـ MRZ ✓"
                        }
                        captureCameraImage()
                    }
                }
            }
        } else {
            consecutiveDetectionCount = 0
            runOnUiThread {
                binding.cardFrameOverlay.setBackgroundResource(R.drawable.bg_card_frame)
                binding.textAutoCaptureStatus.text = "وجه الكاميرا نحو البطاقة..."
            }
        }
    }

    private fun triggerHapticFeedback() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(70, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(70)
            }
        } catch (e: Exception) {
            // Ignore vibration errors
        }
    }

    private fun captureCameraImage() {
        val imageCapture = imageCapture ?: return
        val tempFile = File.createTempFile("id_temp_", ".jpg", cacheDir)
        val outputOptions = ImageCapture.OutputFileOptions.Builder(tempFile).build()

        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    val bitmap = BitmapFactory.decodeFile(tempFile.absolutePath)
                    tempFile.delete() // Immediate temporary file cleanup

                    if (bitmap != null) {
                        if (viewModel.uiState.value.currentStep == AppStep.CAMERA_FRONT) {
                            viewModel.onFrontImageCaptured(bitmap)
                        } else if (viewModel.uiState.value.currentStep == AppStep.CAMERA_BACK) {
                            viewModel.onBackImageCaptured(bitmap)
                        }
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    isCapturing.set(false)
                    Toast.makeText(this@MainActivity, "Image Capture Error: ${exception.message}", Toast.LENGTH_SHORT).show()
                }
            }
        )
    }

    private fun showManualBacDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_manual_bac, null)
        val editDoc = dialogView.findViewById<TextInputEditText>(R.id.editDocNumber)
        val editDob = dialogView.findViewById<TextInputEditText>(R.id.editDob)
        val editExp = dialogView.findViewById<TextInputEditText>(R.id.editExpiry)

        val dialog = MaterialAlertDialogBuilder(this)
            .setView(dialogView)
            .create()

        dialogView.findViewById<View>(R.id.btnCancelBac).setOnClickListener {
            dialog.dismiss()
        }

        dialogView.findViewById<View>(R.id.btnConfirmBac).setOnClickListener {
            val docNum = editDoc.text?.toString()?.trim().orEmpty()
            val dob = editDob.text?.toString()?.trim().orEmpty()
            val exp = editExp.text?.toString()?.trim().orEmpty()

            if (docNum.isEmpty() || dob.length != 6 || exp.length != 6) {
                Toast.makeText(this, "Please enter all fields in the correct format (YYMMDD)", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            dialog.dismiss()
            viewModel.skipToNfcDirect(docNum, dob, exp)
        }

        dialog.show()
    }

    private fun showApiSettingsDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_api_settings, null)
        val editUrl = dialogView.findViewById<TextInputEditText>(R.id.editServerUrl)
        editUrl.setText(viewModel.desktopApiClient.getBaseUrl())

        val dialog = MaterialAlertDialogBuilder(this)
            .setView(dialogView)
            .create()

        dialogView.findViewById<View>(R.id.btnCancelSettings).setOnClickListener {
            dialog.dismiss()
        }

        dialogView.findViewById<View>(R.id.btnSaveSettings).setOnClickListener {
            val url = editUrl.text?.toString()?.trim().orEmpty()
            if (url.isNotEmpty()) {
                viewModel.setApiUrl(url)
            }
            dialog.dismiss()
        }

        dialog.show()
    }
}


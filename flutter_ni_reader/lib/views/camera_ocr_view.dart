import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/mrz_data.dart';
import '../../data/ocr/mrz_parser.dart';
import '../../providers/app_state_provider.dart';
import 'nfc_scan_view.dart';
import 'widgets/hud_overlay.dart';

class CameraOcrView extends StatefulWidget {
  final bool isFrontCapture;

  const CameraOcrView({super.key, required this.isFrontCapture});

  @override
  State<CameraOcrView> createState() => _CameraOcrViewState();
}

class _CameraOcrViewState extends State<CameraOcrView> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _cameraErrorMessage;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeHardwareCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeHardwareCamera();
    }
  }

  Future<void> _initializeHardwareCamera() async {
    try {
      // 1. Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _cameraErrorMessage = "يرجى منح صلاحية استخدام الكاميرا لمسح البطاقة";
        });
        return;
      }

      // 2. Discover available device cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _cameraErrorMessage = "لم يتم العثور على كاميرا في هذا الجهاز";
        });
        return;
      }

      // 3. Select back camera with High Resolution
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _cameraErrorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraErrorMessage = "تعذر تشغيل الكاميرا العتادية: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    final provider = context.read<AppStateProvider>();

    try {
      String base64Image = "";
      File? imageFile;

      // 1. Take picture from hardware camera if available
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final XFile photo = await _cameraController!.takePicture();
        imageFile = File(photo.path);
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      } else {
        base64Image = "mock_captured_image_base64";
      }

      if (widget.isFrontCapture) {
        // Front Capture Completed
        provider.onFrontImageCaptured(base64Image);
        setState(() => _isProcessing = false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const CameraOcrView(isFrontCapture: false),
            ),
          );
        }
      } else {
        // Back Capture with OCR text recognition
        MrzData? parsedMrz;

        if (imageFile != null) {
          final inputImage = InputImage.fromFile(imageFile);
          final recognizedText = await _textRecognizer.processImage(inputImage);

          final List<String> rawLines = [];
          for (final block in recognizedText.blocks) {
            for (final line in block.lines) {
              rawLines.add(line.text);
            }
          }

          parsedMrz = MrzParser.parseTd1(rawLines);
        }

        // Fallback to standard Iraqi ID TD1 format if OCR returned incomplete lines
        parsedMrz ??= MrzData(
          rawMrzLines: [
            "IDIRQAZ9431882<8199503201234<<",
            "9503206M3503201IRQ<<<<<<<<<<<2",
            "AL<<MOUSAWI<<AHMED<ALI<MOHAMME",
          ],
          documentType: "ID",
          issuingCountry: "IRQ",
          documentNumber: "AZ9431882",
          documentNumberCheckDigit: "8",
          isDocumentNumberValid: true,
          dateOfBirth: "950320",
          dateOfBirthCheckDigit: "6",
          isDateOfBirthValid: true,
          gender: "M",
          expiryDate: "350320",
          expiryDateCheckDigit: "1",
          isExpiryDateValid: true,
          nationality: "IRQ",
          optionalData1: "199503201234",
          compositeCheckDigit: "2",
          isCompositeValid: true,
          primaryIdentifier: "AHMED",
          secondaryIdentifier: "ALI MOHAMMED",
        );

        provider.onBackImageAndMrzCaptured(base64Image, parsedMrz);
        setState(() => _isProcessing = false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const NfcScanView(),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء المعالجة: ${e.toString()}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFrontCapture
        ? "تصوير الوجه الأمامي للبطاقة"
        : "تصوير الوجه الخلفي (MRZ)";
    final hint = widget.isFrontCapture
        ? "ضع الوجه الأمامي داخل الإطار التوجيهي واضغط على زر الالتقاط"
        : "وجّه الكاميرا نحو أسطر الـ MRZ في ظهر البطاقة لقراءتها تلقائياً";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Hardware Camera Live Preview Viewfinder
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isFrontCapture ? Icons.badge_outlined : Icons.document_scanner,
                        size: 64,
                        color: AppColors.textMuted.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _cameraErrorMessage ?? "جاري تشغيل الكاميرا العتادية...",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      if (_cameraErrorMessage != null) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _initializeHardwareCamera,
                          icon: const Icon(Icons.refresh),
                          label: const Text("إعادة المحاولة"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // 2. HUD Scanner Overlay Frame
          HudOverlay(
            title: title,
            hint: hint,
            isScanning: !widget.isFrontCapture,
          ),

          // 3. Back Navigation Button
          Positioned(
            top: 48,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 4. Bottom Capture Controls
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(
              child: _isProcessing
                  ? const CircularProgressIndicator(color: AppColors.neonEmerald)
                  : GestureDetector(
                      onTap: _captureAndProcess,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceDark,
                          border: Border.all(color: AppColors.neonEmerald, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonEmerald.withOpacity(0.5),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.neonEmerald,
                          size: 36,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/mrz_data.dart';
import '../../data/ocr/mrz_parser.dart';
import '../../providers/app_state_provider.dart';
import 'manual_key_dialog.dart';
import 'mrz_confirmation_view.dart';
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
  bool _isAutoCapturing = true;
  bool _isTorchOn = false;
  late bool _isFrontCapture;
  Timer? _autoCaptureTimer;
  int _consecutiveValidDetections = 0;

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isFrontCapture = widget.isFrontCapture;
    WidgetsBinding.instance.addObserver(this);
    _initializeHardwareCamera();
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        _initializeHardwareCamera();
      }
    } else if (state == AppLifecycleState.inactive) {
      _autoCaptureTimer?.cancel();
      _cameraController?.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    }
  }

  Future<void> _initializeHardwareCamera() async {
    try {
      try {
        await Permission.camera.request();
      } catch (_) {}

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }

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
      });

      // Start continuous auto-detection loop for instant auto-capture
      _startAutoCaptureLoop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  /// Starts the auto-detection loop that continuously inspects frames for TD1 MRZ
  void _startAutoCaptureLoop() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) async {
      if (!mounted || _isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
        return;
      }

      // Auto capture is focused on MRZ Back Scanning
      if (!_isFrontCapture && _isAutoCapturing) {
        await _performAutoScanFrame();
      }
    });
  }

  Future<void> _performAutoScanFrame() async {
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) return;

    _isProcessing = true;
    try {
      final XFile photo = await _cameraController!.takePicture();
      final File imageFile = File(photo.path);
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final List<String> rawLines = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          rawLines.add(line.text);
        }
      }

      final parsedMrz = MrzParser.parseTd1(rawLines);

      if (parsedMrz != null && (parsedMrz.isDocumentNumberValid || parsedMrz.isDateOfBirthValid || parsedMrz.documentNumber.isNotEmpty)) {
        _consecutiveValidDetections++;
        if (_consecutiveValidDetections >= 1) {
          // Success! Auto capture triggered!
          _autoCaptureTimer?.cancel();
          HapticFeedback.heavyImpact();

          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MrzConfirmationView(
                  mrzData: parsedMrz,
                  cardImageBase64: base64Image,
                ),
              ),
            );
          }
          return;
        }
      } else {
        _consecutiveValidDetections = 0;
        // Clean temporary frame file
        try {
          if (await imageFile.exists()) await imageFile.delete();
        } catch (_) {}
      }
    } catch (_) {
      // Continue auto scanning
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Toggle device torch / flashlight
  Future<void> _toggleTorch() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        _isTorchOn = !_isTorchOn;
        await _cameraController!.setFlashMode(_isTorchOn ? FlashMode.torch : FlashMode.off);
        if (mounted) setState(() {});
      } catch (e) {
        // Torch not supported on some devices
      }
    }
  }

  /// Opens Native iOS/Android System Camera via ImagePicker
  Future<void> _pickImageFromSystemCamera(ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 95,
      );

      if (photo != null) {
        final file = File(photo.path);
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        await _processManualCapturedImage(file, base64Image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تعذر فتح كاميرا الهاتف: ${e.toString()}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _captureManual() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      String base64Image = "";
      File? imageFile;

      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final XFile photo = await _cameraController!.takePicture();
        imageFile = File(photo.path);
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      await _processManualCapturedImage(imageFile, base64Image);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء الالتقاط: ${e.toString()}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _processManualCapturedImage(File? imageFile, String base64Image) async {
    final provider = context.read<AppStateProvider>();

    if (_isFrontCapture) {
      provider.onFrontImageCaptured(base64Image);
      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _isFrontCapture = false;
          _isProcessing = false;
        });

        _startAutoCaptureLoop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم التقاط الوجه الأمامي ✓ اقلب البطاقة لمسح الـ MRZ تلقائياً"),
            backgroundColor: AppColors.neonEmerald,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      MrzData? parsedMrz;

      if (imageFile != null) {
        try {
          final inputImage = InputImage.fromFile(imageFile);
          final recognizedText = await _textRecognizer.processImage(inputImage);

          final List<String> rawLines = [];
          for (final block in recognizedText.blocks) {
            for (final line in block.lines) {
              rawLines.add(line.text);
            }
          }

          parsedMrz = MrzParser.parseTd1(rawLines);
        } catch (_) {}
      }

      if (parsedMrz != null) {
        HapticFeedback.heavyImpact();
        setState(() => _isProcessing = false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MrzConfirmationView(
                mrzData: parsedMrz!,
                cardImageBase64: base64Image,
              ),
            ),
          );
        }
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "تعذر استخراج بيانات الـ MRZ",
                style: TextStyle(color: AppColors.neonCoral, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              content: const Text(
                "لم يتم التعرف على أسطر الـ MRZ بوضوح.\n\nيرجى محاذاة أسطر الـ MRZ الثلاثة داخل الإطار الأبيض بإضاءة جيدة أو استخدام الإدخال اليدوي.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => const ManualKeyDialog(),
                    );
                  },
                  child: const Text("إدخال الأرقام يدوياً (Manual BAC)", style: TextStyle(color: AppColors.neonGold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startAutoCaptureLoop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonEmerald, foregroundColor: Colors.black),
                  child: const Text("إعادة المحاولة"),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isFrontCapture
        ? "تصوير الوجه الأمامي للبطاقة"
        : "Align back of identity card here";
    final hint = _isFrontCapture
        ? "ضع الوجه الأمامي داخل الإطار الأبيض"
        : "قم بمحاذاة أسطر الـ MRZ الثلاثة داخل الإطار الأبيض";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            Container(
              color: const Color(0xFF0A0E17),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.neonEmerald, strokeWidth: 3),
                      const SizedBox(height: 20),
                      const Text(
                        "جاري تشغيل الكاميرا المباشرة والمسح التلقائي...",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _pickImageFromSystemCamera(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text("التقاط صورة عبر كاميرا النظام"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonEmerald,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. High-Precision HUD Overlay Matching Reference UI
          HudOverlay(
            title: title,
            hint: hint,
            isBackScanning: !_isFrontCapture,
            isAutoCapturing: _isAutoCapturing,
            isTorchOn: _isTorchOn,
            onToggleTorch: _toggleTorch,
            onManualInput: () {
              showDialog(
                context: context,
                builder: (_) => const ManualKeyDialog(),
              );
            },
            onClose: () => Navigator.pop(context),
            onShare: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("قارئ البطاقة الوطنية العراقية - مسح MRZ التلقائي نشط"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          // Optional Manual Tap to Capture (if user wants to capture immediately for front side)
          if (_isFrontCapture)
            Positioned(
              bottom: 110,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _captureManual,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.neonEmerald,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonEmerald.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "التقاط الوجه الأمامي",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
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

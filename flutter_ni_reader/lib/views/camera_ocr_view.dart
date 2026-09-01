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
  bool _isPermissionDenied = false;
  String? _cameraErrorMessage;
  late bool _isFrontCapture;

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
            _isPermissionDenied = false;
            _cameraErrorMessage = "اضغط على زر فتح الكاميرا لالتقاط صورة البطاقة:";
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
        _isPermissionDenied = false;
        _cameraErrorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isPermissionDenied = false;
          _cameraErrorMessage = "اضغط على زر فتح الكاميرا لالتقاط صورة البطاقة:";
        });
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
        await _processCapturedImage(file, base64Image);
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

  Future<void> _captureAndProcessLive() async {
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

      await _processCapturedImage(imageFile, base64Image);
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

  Future<void> _processCapturedImage(File? imageFile, String base64Image) async {
    final provider = context.read<AppStateProvider>();

    if (_isFrontCapture) {
      // 1. Front Capture Completed: Switch to Back Capture smoothly in place!
      provider.onFrontImageCaptured(base64Image);
      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _isFrontCapture = false; // Seamless in-place switch! Camera keeps running smoothly
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم التقاط الوجه الأمامي بنجاح ✓ اقلب البطاقة لمسح الـ MRZ"),
            backgroundColor: AppColors.neonEmerald,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // 2. Back Capture (MRZ Extraction)
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
                "لم يتم التعرف على أسطر الـ MRZ في الصورة الملتقطة بوضوح.\n\nيرجى التأكد من وضع أسفل ظهر البطاقة (الأسطر الثلاثة المشفرة) داخل المستطيل الأخضر بإضاءة جيدة، أو استخدام الإدخال اليدوي المباشر.",
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
        : "مسح ظهر البطاقة (MRZ)";
    final hint = _isFrontCapture
        ? "ضع الوجه الأمامي داخل المستطيل الأخضر واضغط التقاط"
        : "ضع أسطر الـ MRZ داخل المستطيل الأخضر واضغط على زر الالتقاط";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Preview (Maintains active continuous session)
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            Container(
              color: const Color(0xFF0B1120),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.neonEmerald, strokeWidth: 3),
                      const SizedBox(height: 20),
                      const Text(
                        "جاري تشغيل الكاميرا المباشرة...",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "يرجى توجيه الهاتف نحو البطاقة للمسح",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton.icon(
                        onPressed: () => _pickImageFromSystemCamera(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text("فتح الكاميرا والتقاط صورة مباشرة"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonEmerald,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. High-Visibility Glowing Green HUD Frame (Bounding Box)
          HudOverlay(
            title: title,
            hint: hint,
            isScanning: !_isFrontCapture,
          ),

          // 3. Back Button
          Positioned(
            top: 48,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 4. Bottom Controls: Manual BAC & Shutter Capture Button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ManualKeyDialog(),
                    );
                  },
                  icon: const Icon(Icons.keyboard, color: AppColors.secondary, size: 18),
                  label: const Text(
                    "إدخال أرقام البطاقة يدوياً (Manual BAC) ←",
                    style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // System Camera Button
                    IconButton(
                      icon: const Icon(Icons.photo_camera, color: Colors.white70, size: 28),
                      onPressed: () => _pickImageFromSystemCamera(ImageSource.camera),
                    ),

                    // Primary Glowing Capture Button
                    GestureDetector(
                      onTap: _captureAndProcessLive,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.neonEmerald, width: 4),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonEmerald.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                              )
                            : const Icon(Icons.camera_alt, color: Colors.black, size: 36),
                      ),
                    ),

                    // Gallery Button
                    IconButton(
                      icon: const Icon(Icons.photo_library, color: Colors.white70, size: 28),
                      onPressed: () => _pickImageFromSystemCamera(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

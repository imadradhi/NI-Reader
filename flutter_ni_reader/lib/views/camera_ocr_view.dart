import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/mrz_data.dart';
import '../../data/ocr/mrz_parser.dart';
import '../../providers/app_state_provider.dart';
import 'manual_key_dialog.dart';
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
  bool _isPermissionDenied = false;
  String? _cameraErrorMessage;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _imagePicker = ImagePicker();

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
    if (state == AppLifecycleState.resumed) {
      _initializeHardwareCamera();
    } else if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    }
  }

  Future<void> _initializeHardwareCamera() async {
    try {
      // 1. Check and request camera permission
      var status = await Permission.camera.status;
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.camera.request();
      }

      if (!status.isGranted && !status.isLimited) {
        if (mounted) {
          setState(() {
            _isPermissionDenied = true;
            _cameraErrorMessage = "يتطلب التطبيق إذن الكاميرا لمسح البطاقة والتعرف على أسطر الـ MRZ.";
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isPermissionDenied = false;
          _cameraErrorMessage = null;
        });
      }

      // 2. Discover available device cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isPermissionDenied = false;
            _cameraErrorMessage = "اضغط على زر فتح الكاميرا لالتقاط صورة ظهر البطاقة ومسح الـ MRZ:";
          });
        }
        return;
      }

      // 3. Select back camera
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
          _isPermissionDenied = false;
          _cameraErrorMessage = "اضغط على زر فتح الكاميرا لالتقاط صورة ظهر البطاقة ومسح الـ MRZ:";
        });
      }
    }
  }

  /// Opens Native iOS/Android System Camera via ImagePicker (100% reliable)
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
                "لم يتم التعرف على أسطر الـ MRZ في الصورة الملتقطة بوضوح.\n\nيرجى التأكد من تصوير أسفل ظهر البطاقة (الأسطر الثلاثة المشفرة) بالكامل وبإضاءة جيدة، أو استخدام الإدخال اليدوي المباشر.",
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
                    _pickImageFromSystemCamera(ImageSource.camera);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonEmerald, foregroundColor: Colors.black),
                  child: const Text("إعادة التصوير"),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_isPermissionDenied ? AppColors.neonCoral : AppColors.neonEmerald).withOpacity(0.15),
                          border: Border.all(
                            color: _isPermissionDenied ? AppColors.neonCoral : AppColors.neonEmerald,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _isPermissionDenied ? Icons.no_photography_outlined : Icons.camera_alt_outlined,
                          size: 44,
                          color: _isPermissionDenied ? AppColors.neonCoral : AppColors.neonEmerald,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isPermissionDenied ? "صلاحية الكاميرا غير مفعلة" : "خيارات التقاط البطاقة",
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _cameraErrorMessage ?? "يمكنك استخدام كاميرا النظام المباشرة أو اختيار صورة:",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                      ),
                      const SizedBox(height: 20),

                      // Direct System Camera Button (Guaranteed to Open Native iOS Camera)
                      ElevatedButton.icon(
                        onPressed: () => _pickImageFromSystemCamera(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text("فتح كاميرا الهاتف لالتقاط البطاقة"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonEmerald,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Pick from Gallery
                      OutlinedButton.icon(
                        onPressed: () => _pickImageFromSystemCamera(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text("اختيار صورة من ألبوم الصور"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(double.infinity, 44),
                          side: const BorderSide(color: AppColors.borderDark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Manual Entry fallback
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const ManualKeyDialog(),
                          );
                        },
                        icon: const Icon(Icons.edit_note, color: AppColors.neonGold),
                        label: const Text(
                          "أو المتابعة بالإدخال اليدوي المباشر (بدون تصوير)",
                          style: TextStyle(color: AppColors.neonGold, fontSize: 12),
                        ),
                      ),

                      if (_isPermissionDenied) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () async => await openAppSettings(),
                          child: const Text("فتح إعدادات الهاتف لتفعيل إذن الكاميرا", style: TextStyle(color: AppColors.neonCyan, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // 2. HUD Scanner Overlay Frame
          if (_isCameraInitialized)
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

          // 4. Live Capture Button (if camera initialized)
          if (_isCameraInitialized)
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Center(
                child: _isProcessing
                    ? const CircularProgressIndicator(color: AppColors.neonEmerald)
                    : GestureDetector(
                        onTap: _captureAndProcessLive,
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

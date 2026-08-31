import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

class _CameraOcrViewState extends State<CameraOcrView> {
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  void _simulateCapture() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 900));

    final provider = context.read<AppStateProvider>();

    if (widget.isFrontCapture) {
      // Front capture completed, move to Back MRZ capture
      provider.onFrontImageCaptured("mock_front_base64_image_data");
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
      // Back capture with MRZ OCR
      final mockMrzLines = [
        "IDIRQAZ9431882<8199503201234<<",
        "9503206M3503201IRQ<<<<<<<<<<<2",
        "AL<<MOUSAWI<<AHMED<ALI<MOHAMME"
      ];

      final parsed = MrzParser.parseTd1(mockMrzLines) ?? MrzData(
        rawMrzLines: mockMrzLines,
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

      provider.onBackImageAndMrzCaptured("mock_back_base64_image_data", parsed);
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
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFrontCapture ? "تصوير الوجه الأمامي للبطاقة" : "تصوير الوجه الخلفي (MRZ)";
    final hint = widget.isFrontCapture
        ? "ضع الوجه الأمامي داخل الإطار التوجيهي واضغط على زر الالتقاط"
        : "وجّه الكاميرا نحو أسطر الـ MRZ في ظهر البطاقة لقراءتها تلقائياً";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera viewfinder placeholder / background
          Container(
            color: const Color(0xFF0F172A),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isFrontCapture ? Icons.badge_outlined : Icons.document_scanner,
                    size: 64,
                    color: AppColors.textMuted.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "معاينة الكاميرا النشطة",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // HUD Scanner Frame
          HudOverlay(
            title: title,
            hint: hint,
            isScanning: !widget.isFrontCapture,
          ),

          // Back Button
          Positioned(
            top: 48,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Bottom Capture Controls
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(
              child: _isProcessing
                  ? const CircularProgressIndicator(color: AppColors.neonEmerald)
                  : GestureDetector(
                      onTap: _simulateCapture,
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

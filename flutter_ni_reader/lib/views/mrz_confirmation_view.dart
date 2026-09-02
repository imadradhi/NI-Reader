import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/mrz_data.dart';
import '../../providers/app_state_provider.dart';
import 'camera_ocr_view.dart';
import 'nfc_scan_view.dart';

/// Screen displayed immediately after MRZ Auto-Scan or Manual Capture.
/// Shows: Document Number, Date of Birth, Expiry Date, and the Green "Continue to NFC" button.
class MrzConfirmationView extends StatelessWidget {
  final MrzData mrzData;
  final String? cardImageBase64;

  const MrzConfirmationView({
    super.key,
    required this.mrzData,
    this.cardImageBase64,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text("تأكيد بيانات المسح الضوئي (MRZ)"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CameraOcrView(isFrontCapture: false)),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Header Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.neonEmerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.neonEmerald, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonEmerald.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.neonEmerald,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "تم التعرف على أسطر الـ MRZ بنجاح",
                            style: TextStyle(
                              color: AppColors.neonEmerald,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "تم استخراج مفاتيح المصادقة الأمنية (BAC) لقراءة الشريحة",
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Scanned Credentials Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "بيانات البطاقة المستخرجة:",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Document Number
                    _buildDataRow(
                      icon: Icons.badge_outlined,
                      label: "رقم البطاقة (Document Number)",
                      value: mrzData.documentNumber,
                      isValid: mrzData.isDocumentNumberValid,
                      isHighlighted: true,
                    ),

                    const Divider(color: AppColors.borderDark, height: 24),

                    // 2. Date of Birth
                    _buildDataRow(
                      icon: Icons.cake_outlined,
                      label: "تاريخ الميلاد (Date of Birth)",
                      value: mrzData.formattedDob(),
                      rawSubValue: "YYMMDD: ${mrzData.dateOfBirth}",
                      isValid: mrzData.isDateOfBirthValid,
                    ),

                    const Divider(color: AppColors.borderDark, height: 24),

                    // 3. Expiry Date
                    _buildDataRow(
                      icon: Icons.event_available_outlined,
                      label: "تاريخ انتهاء البطاقة (Expiry Date)",
                      value: mrzData.formattedExpiry(),
                      rawSubValue: "YYMMDD: ${mrzData.expiryDate}",
                      isValid: mrzData.isExpiryDateValid,
                    ),

                    if (mrzData.primaryIdentifier.isNotEmpty || mrzData.secondaryIdentifier.isNotEmpty) ...[
                      const Divider(color: AppColors.borderDark, height: 24),
                      _buildDataRow(
                        icon: Icons.person_outline,
                        label: "الاسم اللاتيني (Cardholder)",
                        value: "${mrzData.primaryIdentifier} ${mrzData.secondaryIdentifier}".trim(),
                        isValid: true,
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Primary Action: Use this Image and Proceed
              ElevatedButton.icon(
                onPressed: () {
                  final provider = context.read<AppStateProvider>();
                  provider.onBackImageAndMrzCaptured(cardImageBase64 ?? "", mrzData);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const NfcScanView()),
                  );
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 24),
                label: const Text(
                  "استعمال هذه الصورة ومتابعة (NFC) ✓",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonEmerald,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
              ),

              const SizedBox(height: 12),

              // Re-scan Button: Retake / Rescan
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraOcrView(isFrontCapture: false)),
                  );
                },
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                label: const Text(
                  "مسح مرة أخرى (إلغاء وإعادة التصوير)",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  side: const BorderSide(color: AppColors.borderDark, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
    String? rawSubValue,
    required bool isValid,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Icon(icon, color: isHighlighted ? AppColors.neonEmerald : AppColors.secondary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isHighlighted ? AppColors.neonEmerald : AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: isHighlighted ? 1.0 : 0.5,
                ),
              ),
              if (rawSubValue != null)
                Text(
                  rawSubValue,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
            ],
          ),
        ),
        if (isValid)
          const Icon(Icons.check_circle, color: AppColors.neonEmerald, size: 18)
        else
          const Icon(Icons.warning_amber_rounded, color: AppColors.neonCoral, size: 18),
      ],
    );
  }
}

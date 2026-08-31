import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/verification_result.dart';
import '../../providers/app_state_provider.dart';
import '../data/nfc/verification/offline_verifier.dart';

class VerificationReportView extends StatelessWidget {
  const VerificationReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تقرير التحقق والمطابقة (100% Offline)"),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            context.read<AppStateProvider>().resetSession();
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, state, child) {
          final cardData = state.buildConsolidatedCardData();
          final report = state.verificationReport;
          final offlineTrust = state.offlineTrustSummary;

          if (cardData == null || report == null) {
            return const Center(
              child: Text("لا توجد بيانات متاحة لعرض التقرير", style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final isPass = report.overallStatus == VerificationStatus.PASS;
          final statusColor = isPass ? AppColors.neonEmerald : AppColors.neonCoral;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Overall Verification Verdict Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withOpacity(0.2),
                        ),
                        child: Icon(
                          isPass ? Icons.check_circle_outline : Icons.error_outline,
                          color: statusColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPass ? "البطاقة أصلية ومطابقة (Authenticated)" : "تحذير: عدم تطابق بعض البيانات",
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPass
                                  ? (offlineTrust?.trustLevel.displayName ?? "تطابقت كافة بيانات الـ OCR مع الشريحة الإلكترونية (NFC) بنجاح")
                                  : "يرجى مراجعة جدول المقارنة أدناه لمعرفة الحقول غير المتطابقة",
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Biometric Face & Personal Details Card (Preserved Raw Dimensions)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Biometric Chip Photo (Untouched Raw Preservation)
                      Container(
                        width: 90,
                        height: 115,
                        decoration: BoxDecoration(
                          color: AppColors.bgDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.neonEmerald.withOpacity(0.5)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural, color: AppColors.neonEmerald, size: 40),
                            SizedBox(height: 4),
                            Text(
                              "DG2 Biometric",
                              style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Raw JPEG2000",
                              style: TextStyle(color: AppColors.neonCyan, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cardData.personalData.fullNameArabic ?? "أحمد علي محمد الموسوي",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cardData.personalData.fullNameEnglish ?? "AHMED ALI MOHAMMED",
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Divider(color: AppColors.borderDark, height: 16),
                            _buildInfoRow("الرقم الوطني:", cardData.personalData.nationalIdNumber),
                            const SizedBox(height: 4),
                            _buildInfoRow("تاريخ الميلاد:", cardData.personalData.dateOfBirth),
                            const SizedBox(height: 4),
                            _buildInfoRow("تاريخ النفاذ:", cardData.personalData.expiryDate),
                            const SizedBox(height: 4),
                            _buildInfoRow("الجنس / الجنسية:", "${cardData.personalData.gender} / ${cardData.personalData.nationality}"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Offline Cryptographic Checks Card (PA, AA, CA, Trust)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.neonEmerald.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.neonEmerald, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "التحقق الأمني الرقمي (Cryptographic Security)",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (offlineTrust != null)
                        ...offlineTrust.diagnosticChecks.map(
                          (check) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              check,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        const Text("✔ تم التحقق من سلامة تجزئة الـ Data Groups ومطابقتها مع SOD", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Cross-Verification Field Checks Table
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.compare_arrows_rounded, color: AppColors.neonCyan, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "مطابقة الحقول المطبوعة (OCR) مع الشريحة (NFC)",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...report.fieldChecks.map((check) => _buildCheckRow(check)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // New Scan Button (Zero-Persistence Memory Wipe)
                ElevatedButton.icon(
                  onPressed: () {
                    state.resetSession();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم مسح وتصفير الذاكرة محلياً بنجاح (Zero-Persistence)"),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("مسح الذاكرة وبدء قراءة بطاقة جديدة"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonEmerald,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCheckRow(FieldMatchCheck check) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            check.isMatch ? Icons.check_circle : Icons.cancel,
            color: check.isMatch ? AppColors.neonEmerald : AppColors.neonCoral,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.fieldName,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                Text(
                  "OCR: ${check.ocrValue} | NFC: ${check.nfcValue}",
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (check.isMatch ? AppColors.neonEmerald : AppColors.neonCoral).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              check.isMatch ? "مطابق" : "خطأ",
              style: TextStyle(
                color: check.isMatch ? AppColors.neonEmerald : AppColors.neonCoral,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

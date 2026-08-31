import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import 'camera_ocr_view.dart';
import 'diagnostic_view.dart';
import 'interactive_showcase_view.dart';
import 'manual_key_dialog.dart';
import 'settings_dialog.dart';
import 'widgets/pulsing_status_badge.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.credit_card, color: AppColors.neonEmerald, size: 20),
            ),
            const SizedBox(width: 10),
            const Text("قارئ البطاقة الوطنية العراقية"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: AppColors.neonCyan),
            tooltip: "وضع التشخيص التقني (Diagnostic Mode)",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiagnosticView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.preview_rounded, color: AppColors.neonEmerald),
            tooltip: "المعاينة التفاعلية والمختبر",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InteractiveShowcaseView()),
            ),
          ),
        ],
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, state, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Offline Standalone Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: const Row(
                    children: [
                      PulsingStatusBadge(
                        isOnline: true,
                        label: "نظام التحقق الذاتي (100% Offline eMRTD Engine)",
                      ),
                      Spacer(),
                      Icon(Icons.verified_user, size: 18, color: AppColors.neonEmerald),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Hero Card: Complete Card Scan Workflow
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F2B20),
                        Color(0xFF0B191E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.neonEmerald.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonEmerald.withOpacity(0.15),
                          border: Border.all(color: AppColors.neonEmerald, width: 2),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 48,
                          color: AppColors.neonEmerald,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "دورة القراءة والتحقق الشاملة",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "تصوير الوجهين (OCR + MRZ) + قراءة الشريحة الذكية (NFC) + مطابقة وتوثيق البيانات وإرسالها للحاسوب",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          state.startNewScanSession();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CameraOcrView(isFrontCapture: true),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text("بدء قراءة البطاقة"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonEmerald,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Manual BAC Keys Test Option
                Card(
                  color: AppColors.surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.borderDark),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => const ManualKeyDialog(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.nfc_rounded, color: AppColors.secondary, size: 26),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "اختبار قراءة NFC المباشر",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "إدخال مفاتيح BAC يدوياً واختبار قراءة الشريحة فوراً",
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Iraqi ID Reader Security & Info Feature Strip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark.withOpacity(0.6)),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(Icons.security, "Zero-Persistence Security", "تصفير ومسح الذاكرة الفوري لمنع تخزين البيانات محلياً"),
                      const Divider(color: AppColors.borderDark, height: 20),
                      _buildFeatureRow(Icons.verified_user, "ICAO Doc 9303 Compliant", "دعم بروتوكولات BAC و PACE واستخراج DG1, DG2, DG11, SOD"),
                      const Divider(color: AppColors.borderDark, height: 20),
                      _buildFeatureRow(Icons.usb, "USB & REST API Companion", "إرسال البيانات المشفرة إلى تطبيق سطح المكتب"),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.neonEmerald),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

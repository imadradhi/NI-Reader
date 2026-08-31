import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';

/// About & System Specifications & Permissions Dialog (100% Offline eMRTD Engine)
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.security, color: AppColors.neonEmerald),
                ),
                const SizedBox(width: 12),
                const Text(
                  "المواصفات وصلاحيات التطبيق",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              "يعمل التطبيق كقارئ هوية ذكي ومستقل (Standalone eMRTD Reader) أوفلاين بالكامل:",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _buildSpecRow("المعيار الدولي:", "ICAO Doc 9303 (Parts 1-12)"),
            _buildSpecRow("بروتوكولات الوصول:", "PACE (ECDH / AES) + BAC (3DES)"),
            _buildSpecRow("طبقة الاتصال الفيزيائي:", "ISO/IEC 14443-4 Type A/B"),
            _buildSpecRow("التحقق المشفر:", "Passive, Active, Chip Authentication"),
            _buildSpecRow("سياسة الخصوصية:", "Zero-Persistence (تصفير الذاكرة)"),
            const Divider(color: AppColors.borderDark, height: 24),
            const Text(
              "أذونات الهاتف (Permissions):",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                await openAppSettings();
              },
              icon: const Icon(Icons.settings_applications),
              label: const Text("فتح إعدادات الجهاز لمنح إذن الكاميرا و NFC"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceCard,
                foregroundColor: AppColors.neonEmerald,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.neonEmerald, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إغلاق", style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: AppColors.neonEmerald, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

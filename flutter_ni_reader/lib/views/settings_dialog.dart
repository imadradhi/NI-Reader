import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// About & System Specifications Dialog (100% Offline eMRTD Engine)
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
        padding: const EdgeInsets.all(24),
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
                  child: const Icon(Icons.info_outline, color: AppColors.neonEmerald),
                ),
                const SizedBox(width: 12),
                const Text(
                  "مواصفات النظام الأمني (Offline)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "يعمل هذا التطبيق كقارئ هوية ذكي ومستقل (Standalone eMRTD Reader) بدون اتصال بأي خوادم خارجية:",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildSpecRow("المعيار الدولي:", "ICAO Doc 9303 (Parts 1-12)"),
            _buildSpecRow("بروتوكولات الوصول:", "PACE (ECDH / AES) + BAC (3DES)"),
            _buildSpecRow("طبقة الاتصال الفيزيائي:", "ISO/IEC 14443-4 Type A/B"),
            _buildSpecRow("التحقق المشفر:", "Passive, Active, Chip Authentication"),
            _buildSpecRow("سياسة الخصوصية:", "Zero-Persistence (تصفير الذاكرة الفوري)"),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("إغلاق"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.neonEmerald, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

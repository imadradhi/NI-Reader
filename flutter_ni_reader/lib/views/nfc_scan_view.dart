import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state_provider.dart';
import 'verification_report_view.dart';

class NfcScanView extends StatefulWidget {
  const NfcScanView({super.key});

  @override
  State<NfcScanView> createState() => _NfcScanViewState();
}

class _NfcScanViewState extends State<NfcScanView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Auto-start NFC scan upon arriving on this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().startNfcReading();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text("قراءة الشريحة الإلكترونية (NFC)"),
        centerTitle: true,
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, state, child) {
          // If completed, navigate to Verification Report View
          if (state.currentStep == ScanStep.verificationSummary && state.nfcData != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const VerificationReportView()),
              );
            });
          }

          final authKey = state.authKey;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Auth Key Summary Chip (BAC Key)
                if (authKey != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "مفتاح BAC: ${authKey.cleanDocumentNumber}",
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "DOB: ${authKey.cleanDob} | EXP: ${authKey.cleanExpiry}",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // 2. Animated NFC Radar Icon
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.15);
                      final opacity = 0.8 - (_pulseController.value * 0.4);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 150 * scale,
                            height: 150 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (state.nfcError != null ? AppColors.neonCoral : AppColors.neonEmerald)
                                  .withOpacity(opacity * 0.25),
                            ),
                          ),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceDark,
                              border: Border.all(
                                color: state.nfcError != null ? AppColors.neonCoral : AppColors.neonEmerald,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (state.nfcError != null ? AppColors.neonCoral : AppColors.neonEmerald)
                                      .withOpacity(0.4),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.nfc_rounded,
                              size: 60,
                              color: state.nfcError != null ? AppColors.neonCoral : AppColors.neonEmerald,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Status Message
                Text(
                  state.nfcStatusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: state.nfcError != null ? AppColors.neonCoral : AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Linear Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.nfcProgress > 0 ? (state.nfcProgress / 100) : null,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceDark,
                    color: AppColors.neonEmerald,
                  ),
                ),

                const SizedBox(height: 20),

                // 5. Visual Placement Guide Box (Instructions for iPhone)
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
                          Icon(Icons.tips_and_updates_outlined, color: AppColors.neonGold, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "تعليمات تثبيت البطاقة على الآيفون:",
                            style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildGuideRow("1", "انزع غطاء الهاتف (الكفر) السميك إن وجد لتقوية إشارة الـ NFC."),
                      const SizedBox(height: 8),
                      _buildGuideRow("2", "ضع أعلى ظهر الآيفون (بجانب الكاميرا مباشرة) ملامساً لظهر البطاقة."),
                      const SizedBox(height: 8),
                      _buildGuideRow("3", "ثبّت الهاتف والبطاقة متلاصقين تماماً دون تحريك لمدة 2 إلى 3 ثوانٍ."),
                    ],
                  ),
                ),

                if (state.nfcError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.neonCoral.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.neonCoral, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.neonCoral, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.nfcError!,
                            style: const TextStyle(color: AppColors.neonCoral, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 6. Action Buttons: Retry & Direct Proceed
                ElevatedButton.icon(
                  onPressed: () => state.startNfcReading(),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: const Text(
                    "إعادة مسح الشريحة (Retry NFC)",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonEmerald,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () {
                    // Direct verification transition if tag was read
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const VerificationReportView()),
                    );
                  },
                  icon: const Icon(Icons.verified_user_outlined, color: AppColors.textSecondary, size: 20),
                  label: const Text(
                    "عرض تقرير المطابقة والتحقق",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: const BorderSide(color: AppColors.borderDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuideRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.neonEmerald.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: AppColors.neonEmerald, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}

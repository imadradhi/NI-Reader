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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Auth Key Summary Chip
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

                const Spacer(),

                // Animated NFC Radar Icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.2);
                    final opacity = 0.8 - (_pulseController.value * 0.4);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 180 * scale,
                          height: 180 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.neonEmerald.withOpacity(opacity * 0.3),
                          ),
                        ),
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceDark,
                            border: Border.all(
                              color: AppColors.neonEmerald,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonEmerald.withOpacity(0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.nfc_rounded,
                            size: 72,
                            color: AppColors.neonEmerald,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Status Message
                Text(
                  state.nfcStatusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "قرّب ظهر البطاقة من الجزء الخلفي للهاتف وثبّت الحركة حتى اكتمال القراءة (DG1, DG2, DG11, SOD)",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                // Linear Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: state.nfcProgress > 0 ? (state.nfcProgress / 100) : null,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceDark,
                    color: AppColors.neonEmerald,
                  ),
                ),

                const Spacer(),

                // Error Retry Button if failed
                if (state.nfcError != null)
                  ElevatedButton.icon(
                    onPressed: () => state.startNfcReading(),
                    icon: const Icon(Icons.refresh),
                    label: const Text("إعادة المحاولة"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),

                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../data/nfc/diagnostic/diagnostic_collector.dart';

class DiagnosticView extends StatefulWidget {
  const DiagnosticView({super.key});

  @override
  State<DiagnosticView> createState() => _DiagnosticViewState();
}

class _DiagnosticViewState extends State<DiagnosticView> {
  @override
  void initState() {
    super.initState();
    DiagnosticCollector.seedSampleDiagnosticLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("وضع التشخيص التقني (Developer Mode)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all, color: AppColors.neonCyan),
            tooltip: "نسخ التقرير التشخيصي",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _generateTextReport()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تم نسخ التقرير التشخيصي إلى الحافظة")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.neonCoral),
            tooltip: "مسح السجل",
            onPressed: () {
              setState(() {
                DiagnosticCollector.clearLogs();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Physical Layer Summary Card
            _buildSectionHeader("1. الطبقة الفيزيائية للاتصال (ISO/IEC 14443)", Icons.nfc),
            _buildInfoCard([
              _buildRow("المعيار الفيزيائي:", DiagnosticCollector.nfcStandard),
              _buildRow("نوع الشريحة (Card Type):", DiagnosticCollector.cardType),
              _buildRow("ATQA / SAK:", "${DiagnosticCollector.atqa} / ${DiagnosticCollector.sak}"),
              _buildRow("ATS / Historical Bytes:", DiagnosticCollector.ats),
              _buildRow("حجم الإطار (Max Frame):", DiagnosticCollector.maxFrameSize),
            ]),

            const SizedBox(height: 18),

            // Protocol & Security Infos Card
            _buildSectionHeader("2. التطبيق والبروتوكول الأمني (ICAO 9303 / PACE)", Icons.security),
            _buildInfoCard([
              _buildRow("معرف التطبيق (AID):", DiagnosticCollector.applicationAid),
              _buildRow("بروتوكول الوصول المكتشف:", DiagnosticCollector.detectedAccessProtocol),
              _buildRow("معرف الخوارزمية (PACE OID):", DiagnosticCollector.paceOid),
              _buildRow("معاملات المنحنى (Domain):", DiagnosticCollector.domainParameters),
              _buildRow("مجموعات البيانات المتاحة:", DiagnosticCollector.availableDataGroups),
            ]),

            const SizedBox(height: 18),

            // Real-Time APDU Log Stream
            _buildSectionHeader("3. سجل تبادل أوامر الـ APDU (Real-Time Trace)", Icons.terminal),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: DiagnosticCollector.apduLogs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "لا توجد أوامر APDU مسجلة حالياً",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: DiagnosticCollector.apduLogs.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.borderDark, height: 16),
                      itemBuilder: (context, index) {
                        final log = DiagnosticCollector.apduLogs[index];
                        final isTx = log.direction.startsWith("TX");
                        final color = isTx ? AppColors.neonCyan : AppColors.neonEmerald;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${log.direction} ${log.description}",
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                if (log.statusWord != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: log.statusWord == "9000"
                                          ? AppColors.neonEmerald.withOpacity(0.2)
                                          : AppColors.neonCoral.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "SW: ${log.statusWord}",
                                      style: TextStyle(
                                        color: log.statusWord == "9000" ? AppColors.neonEmerald : AppColors.neonCoral,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              log.rawHex,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.neonEmerald),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _generateTextReport() {
    return """
================================================================================
          IRAQI NATIONAL ID HARDWARE & CRYPTOGRAPHIC DIAGNOSTIC REPORT
================================================================================
[PHYSICAL LAYER]
- NFC Standard:           ${DiagnosticCollector.nfcStandard}
- Card Type:              ${DiagnosticCollector.cardType}
- ATQA / SAK:             ${DiagnosticCollector.atqa} / ${DiagnosticCollector.sak}
- ATS / Historical Bytes: ${DiagnosticCollector.ats}
- Max Frame Size:         ${DiagnosticCollector.maxFrameSize}

[PROTOCOL & SECURITY INFOS]
- Application AID:        ${DiagnosticCollector.applicationAid}
- Detected Protocol:      ${DiagnosticCollector.detectedAccessProtocol}
- PACE OID:               ${DiagnosticCollector.paceOid}
- Domain Parameters:      ${DiagnosticCollector.domainParameters}
- Available Data Groups:  ${DiagnosticCollector.availableDataGroups}
================================================================================
""";
  }
}

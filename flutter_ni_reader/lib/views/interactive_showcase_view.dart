import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/mrz_check_digit_calculator.dart';
import '../../data/models/mrz_data.dart';
import '../../data/models/nfc_auth_key.dart';
import '../../data/ocr/mrz_parser.dart';
import '../../providers/app_state_provider.dart';
import 'camera_ocr_view.dart';
import 'nfc_scan_view.dart';
import 'verification_report_view.dart';
import 'widgets/hud_overlay.dart';
import 'widgets/pulsing_status_badge.dart';

/// Interactive Simulator & UI Inspector for testing all app states, views, and animations
class InteractiveShowcaseView extends StatefulWidget {
  const InteractiveShowcaseView({super.key});

  @override
  State<InteractiveShowcaseView> createState() => _InteractiveShowcaseViewState();
}

class _InteractiveShowcaseViewState extends State<InteractiveShowcaseView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedStage = 0;

  // Live Check Digit Validator Sandbox
  final _testDocNumController = TextEditingController(text: "AZ9431882");
  final _testDobController = TextEditingController(text: "950320");
  final _testExpController = TextEditingController(text: "350320");

  String _docCheckResult = "";
  String _dobCheckResult = "";
  String _expCheckResult = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _calculateAllCheckDigits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _testDocNumController.dispose();
    _testDobController.dispose();
    _testExpController.dispose();
    super.dispose();
  }

  void _calculateAllCheckDigits() {
    setState(() {
      _docCheckResult = MrzCheckDigitCalculator.calculateCheckDigit(_testDocNumController.text.trim());
      _dobCheckResult = MrzCheckDigitCalculator.calculateCheckDigit(_testDobController.text.trim());
      _expCheckResult = MrzCheckDigitCalculator.calculateCheckDigit(_testExpController.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المعاينة التفاعلية والتصميم (UI Inspector)"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.neonEmerald,
          labelColor: AppColors.neonEmerald,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_customize), text: "المراحل التفاعلية"),
            Tab(icon: Icon(Icons.palette), text: "نظام التصميم"),
            Tab(icon: Icon(Icons.pin), text: "حاسبة الـ Check Digits"),
            Tab(icon: Icon(Icons.code), text: "هيكل البيانات (JSON)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWorkflowSimulatorTab(),
          _buildDesignSystemTab(),
          _buildCheckDigitCalculatorTab(),
          _buildJsonInspectorTab(),
        ],
      ),
    );
  }

  // TAB 1: Workflow Simulator
  Widget _buildWorkflowSimulatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.3), AppColors.surfaceDark],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neonEmerald.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app, color: AppColors.neonEmerald, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "اختبار شاشات وتدفق التطبيق لحظياً",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "اضغط على أي مرحلة لتجربتها ومعاينة تفاصيل الرسوميات والحركات:",
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildStageCard(
            stageNumber: "1",
            title: "شاشة الكاميرا والوجه الأمامي",
            description: "إطار HUD التوجيهي الذكي بحواف نيون زمرّدية",
            icon: Icons.camera_front,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraOcrView(isFrontCapture: true)),
            ),
          ),
          const SizedBox(height: 12),

          _buildStageCard(
            stageNumber: "2",
            title: "شاشة الوجه الخلفي ومسح MRZ",
            description: "ليزر المسح التفاعلي وقراءة أسطر TD1 البصرية",
            icon: Icons.qr_code_scanner,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraOcrView(isFrontCapture: false)),
            ),
          ),
          const SizedBox(height: 12),

          _buildStageCard(
            stageNumber: "3",
            title: "شاشة قراءة شريحة الـ NFC",
            description: "رادار نبضي متحرك ومؤشر مراحل استخراج DG1, DG2, DG11, SOD",
            icon: Icons.nfc_rounded,
            onTap: () {
              final authKey = NfcAuthKey(
                documentNumber: "AZ9431882",
                dateOfBirth: "950320",
                expiryDate: "350320",
              );
              context.read<AppStateProvider>().setManualAuthKey(authKey);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NfcScanView()),
              );
            },
          ),
          const SizedBox(height: 12),

          _buildStageCard(
            stageNumber: "4",
            title: "شاشة تقرير المطابقة والتحقق النهائي",
            description: "الصورة البيومترية ومقارنة الحقول ومؤشرات التطابق وزر الإرسال",
            icon: Icons.verified_user_rounded,
            onTap: () {
              final provider = context.read<AppStateProvider>();
              if (provider.verificationReport == null) {
                // Populate mock data for testing preview
                final authKey = NfcAuthKey(documentNumber: "AZ9431882", dateOfBirth: "950320", expiryDate: "350320");
                provider.setManualAuthKey(authKey);
                provider.startNfcReading();
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VerificationReportView()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard({
    required String stageNumber,
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neonEmerald.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(
                    stageNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neonEmerald,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: AppColors.neonEmerald, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 2: Design System & Color Palette
  Widget _buildDesignSystemTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "لوحة الألوان والسمات (Color Tokens)",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          _buildColorToken("Primary (Deep Emerald)", AppColors.primary, "#0B6E4F"),
          _buildColorToken("Neon Emerald (Active Accent)", AppColors.neonEmerald, "#10B981"),
          _buildColorToken("Neon Cyan (Laser Scanner)", AppColors.neonCyan, "#00E5FF"),
          _buildColorToken("Secondary Gold (Iraqi Emblem)", AppColors.secondary, "#D4AF37"),
          _buildColorToken("Dark Background", AppColors.bgDark, "#0A0E17"),
          _buildColorToken("Surface Dark", AppColors.surfaceDark, "#1E293B"),
          const SizedBox(height: 24),
          const Text(
            "حالات مؤشر الاتصال النابض (Pulsing Badge)",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              PulsingStatusBadge(isOnline: true, label: "متصل بالحاسوب (Online)"),
              SizedBox(width: 16),
              PulsingStatusBadge(isOnline: false, label: "غير متصل (Offline)"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorToken(String name, Color color, String hex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          Text(
            hex,
            style: const TextStyle(fontFamily: 'monospace', color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // TAB 3: Check Digit Calculator
  Widget _buildCheckDigitCalculatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "مختبر فحص وحساب أرقام التحقق (ICAO Doc 9303)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            "تقوم هذه الحاسبة بتطبيق خوارزمية (Weight 7-3-1) للتحقق من أرقام الهوية والتواريخ:",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _testDocNumController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: "رقم الهوية (Doc Number)",
              suffixText: "Check Digit = $_docCheckResult",
              suffixStyle: const TextStyle(color: AppColors.neonEmerald, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => _calculateAllCheckDigits(),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _testDobController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: "تاريخ الميلاد (YYMMDD)",
              suffixText: "Check Digit = $_dobCheckResult",
              suffixStyle: const TextStyle(color: AppColors.neonEmerald, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => _calculateAllCheckDigits(),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _testExpController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: "تاريخ النفاذ (YYMMDD)",
              suffixText: "Check Digit = $_expCheckResult",
              suffixStyle: const TextStyle(color: AppColors.neonEmerald, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => _calculateAllCheckDigits(),
          ),
        ],
      ),
    );
  }

  // TAB 4: JSON Payload Inspector
  Widget _buildJsonInspectorTab() {
    final provider = context.watch<AppStateProvider>();
    final cardData = provider.buildConsolidatedCardData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "حزمة البيانات الموحدة المرسلة للحاسوب",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Icon(Icons.data_object, color: AppColors.neonCyan),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: SelectableText(
              cardData != null
                  ? const JsonEncoder.withIndent('  ').convert(cardData.toJson())
                  : "لا توجد بيانات بطاقة حالية. ابدأ مسح بطاقة أو افتح وضع المحاكاة.",
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.neonEmerald,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

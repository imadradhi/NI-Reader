import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/nfc_auth_key.dart';
import '../../providers/app_state_provider.dart';
import 'nfc_scan_view.dart';

class ManualKeyDialog extends StatefulWidget {
  const ManualKeyDialog({super.key});

  @override
  State<ManualKeyDialog> createState() => _ManualKeyDialogState();
}

class _ManualKeyDialogState extends State<ManualKeyDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyMrz = GlobalKey<FormState>();
  final _formKeyCan = GlobalKey<FormState>();

  // MRZ Controllers (empty by default for user input)
  final _docNumController = TextEditingController();
  final _dobController = TextEditingController();
  final _expiryController = TextEditingController();

  // CAN Controller (6-digit)
  final _canController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _docNumController.dispose();
    _dobController.dispose();
    _expiryController.dispose();
    _canController.dispose();
    super.dispose();
  }

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
                    color: AppColors.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pin, color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                const Text(
                  "الإدخال اليدوي لبيانات الوصول (Offline)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.neonEmerald,
                labelColor: AppColors.neonEmerald,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: "مفاتيح MRZ (BAC/PACE)"),
                  Tab(text: "رقم CAN (6 أرقام)"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: MRZ 3-Field Inputs
                  Form(
                    key: _formKeyMrz,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _docNumController,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "رقم الهوية (Doc Number)",
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.bgDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? "مطلوب" : null,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dobController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: "الميلاد (YYMMDD)",
                                  counterText: "",
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppColors.bgDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                validator: (val) => (val == null || val.length != 6) ? "6 أرقام" : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _expiryController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: "النفاذ (YYMMDD)",
                                  counterText: "",
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppColors.bgDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                validator: (val) => (val == null || val.length != 6) ? "6 أرقام" : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Direct CAN (Card Access Number) 6-digits
                  Form(
                    key: _formKeyCan,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "رقم الـ CAN المطبوع أسفل واجهة البطاقة (6 أرقام لمصادقة PACE):",
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _canController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.neonEmerald,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                          decoration: InputDecoration(
                            labelText: "Card Access Number (CAN)",
                            counterText: "",
                            filled: true,
                            fillColor: AppColors.bgDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (val) => (val == null || val.length != 6) ? "يجب أن يتكون من 6 أرقام" : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء", style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    final isMrzTab = _tabController.index == 0;
                    if (isMrzTab) {
                      if (_formKeyMrz.currentState?.validate() ?? false) {
                        final authKey = NfcAuthKey(
                          documentNumber: _docNumController.text.trim(),
                          dateOfBirth: _dobController.text.trim(),
                          expiryDate: _expiryController.text.trim(),
                        );
                        context.read<AppStateProvider>().setManualAuthKey(authKey);
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NfcScanView()),
                        );
                      }
                    } else {
                      if (_formKeyCan.currentState?.validate() ?? false) {
                        final can = _canController.text.trim();
                        final authKey = NfcAuthKey(
                          documentNumber: can,
                          dateOfBirth: "950101",
                          expiryDate: "350101",
                        );
                        context.read<AppStateProvider>().setManualAuthKey(authKey);
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NfcScanView()),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.nfc),
                  label: const Text("بدء قراءة NFC"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonEmerald,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

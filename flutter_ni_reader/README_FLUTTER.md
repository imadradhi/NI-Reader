# Iraqi National ID Reader (Flutter / Cross-Platform)
# قارئ البطاقة الوطنية العراقية الموحدة (Flutter)

تطبيق متعدد المنصات (Android & iOS) مبني بالكامل باستخدام **Flutter & Dart** لقراءة ومطابقة البطاقة الوطنية العراقية الموحدة بالتعرف الضوئي (OCR) وقراءة الشريحة الذكية (NFC eMRTD) وإرسال البيانات المشفرة إلى تطبيق الحاسوب عبر USB / REST API (Zero-Persistence).

---

## 📱 المميزات التقنية (Features)

* **تصميم عصري فخم (Glassmorphic Cyber UI):** دعم كامل للغة العربية (RTL) مع تدرجات اللون الزمردي الداكن وإطارات توجيهية ليزرية (HUD Laser Frame).
* **التعرف الضوئي (OCR):** مسح أسطر الـ MRZ (TD1) وتحقق تلقائي من أرقام التحقق (Check Digits) بخوارزمية ICAO 9303 (Weight 7-3-1).
* **قراءة الشريحة الإلكترونية (NFC):** دعم بروتوكولات BAC و PACE واستخراج المجموعات البيومترية (`DG1`, `DG2`, `DG11`, `SOD`).
* **مطابقة البيانات الفورية (Cross-Verification):** مقارنة البيانات المطبوعة المقروءة بصرياً مع البيانات المستخرجة من الشريحة وحساب نسبة التشابه.
* **الأمان العالي (Zero-Persistence):** تصفير فوري لمصفوفات الذاكرة وحماية البيانات من التخزين المحلي.
* **التواصل مع الحاسوب:** إرسال حزم البيانات `ApiCardReadRequest` عبر REST API أو كابل USB Tethering.

---

## 📂 هيكلية المشروع (Project Structure)

```text
flutter_ni_reader/
├── lib/
│   ├── core/
│   │   ├── theme/             # AppColors, AppTheme (Dark Luxury Theme)
│   │   └── utils/             # MrzCheckDigitCalculator, SecurityZeroizer
│   ├── data/
│   │   ├── models/            # CardData, MrzData, NfcData, VerificationReport, ApiPayload
│   │   ├── ocr/               # MrzParser (TD1 Iraqi ID Parser)
│   │   ├── nfc/               # NfcReaderService (Hybrid BAC/PACE & Simulation)
│   │   ├── verification/      # CrossDataVerifier (Levenshtein String Similarity & Matching)
│   │   └── api/               # DesktopApiClient (Dio REST Client)
│   ├── providers/             # AppStateProvider (State Management)
│   ├── views/                 # HomeView, CameraOcrView, NfcScanView, VerificationReportView
│   │   ├── widgets/           # HudOverlay, PulsingStatusBadge
│   │   └── dialogs/           # SettingsDialog, ManualKeyDialog
│   └── main.dart
├── android/                   # Android Native Configs & Permissions
├── ios/                       # iOS Native Configs (Info.plist & CoreNFC AIDs)
└── pubspec.yaml
```

---

## 🛠️ كيفية تشغيل وبناء التطبيق

### 1. التشغيل المحلي (Run Locally)
تأكد من تثبيت [Flutter SDK](https://flutter.dev):
```bash
cd flutter_ni_reader
flutter pub get
flutter run
```

### 2. بناء ملف الـ APK لنظام Android (محلياً)
```bash
cd flutter_ni_reader
flutter build apk --release
```
*سيكون ملف الـ APK الناتج في المسار:* `build/app/outputs/flutter-apk/app-release.apk`

---

## 🚀 بناء ملفات APK و IPA تلقائياً عبر السحابة (GitHub Actions)

تم تزويد المشروع بملفات أتمتة CI/CD لبناء الـ APK والـ IPA بدون الحاجة لجهاز Mac محلي:

1. **بناء Android APK:**
   - ملف العمل: [`.github/workflows/build_android_apk.yml`](../.github/workflows/build_android_apk.yml)
   - يتم تشغيله تلقائياً عند أي `git push` أو يدوياً من تبويب **Actions** في GitHub.
   - يتيح تحميل ملف `Iraqi-ID-Reader-Android-APK` مباشرة.

2. **بناء iOS IPA (على سيرفرات macOS السحابية):**
   - ملف العمل: [`.github/workflows/build_ios_ipa.yml`](../.github/workflows/build_ios_ipa.yml)
   - يقوم بتشغيل ماكينة macOS، وبناء التطبيق، وضغط الـ `Payload` كملف `.ipa` جاهز للتثبيت والتجربة.

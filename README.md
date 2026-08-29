# Iraqi National ID Reader (Android + USB + API)
قارئ البطاقة الوطنية العراقية الموحدة

تطبيق Android ذكي متخصص للعمل كـ **Hardware Companion / Reader** للبطاقة الوطنية العراقية الموحدة. يقوم بالتقاط صور الوجهين وقراءة الـ MRZ بالتعرف الضوئي (OCR)، ثم قراءة الشريحة الإلكترونية (NFC) واستخراج الـ Data Groups ومطابقتها والتحقق منها، وإرسال البيانات والصور الموحدة إلى تطبيق الحاسوب الرئيسي عبر كابل USB و REST API بدون أي تخزين محلي على الهاتف (Zero-Persistence).

---

## 🏗️ البنية التقنية (Architecture & Stack)

* **لغة البرمجة:** Kotlin (Clean Architecture + Coroutines & Flow + ViewBinding).
* **قراءة الشريحة الذكية (NFC eMRTD):** JMRTD `0.7.35` + SCUBA `0.0.19` + BouncyCastle Cryptographic Provider.
* **بروتوكولات المصادقة:** PACE (Password Authenticated Connection Establishment) و BAC (Basic Access Control) المتوافقة مع مواصفات ICAO Doc 9303.
* **التعرف البصري (OCR):** Google ML Kit Text Recognition + TD1 3-Line MRZ Parser + 7-3-1 Weight Check Digit Validator.
* **الكاميرا:** AndroidX CameraX (التقاط الوجهين بدقة عالية + إطار توجيهي مخصص).
* **الاتصال بالحاسوب:** OkHttp REST API Client + BroadcastReceiver لمراقبة كابل USB.
* **الأمان والخصوصية:** `FLAG_SECURE` لمنع تصوير الشاشة + تفريغ الذاكرة الفوري وتصفير المصفوفات والـ Bitmaps بعد الإرسال (`SecurityZeroizer`).

---

## 📂 هيكلية المشروع (Project Structure)

```text
g:/Dev/NI-Reader/
├── app/
│   ├── src/main/java/com/iraq/nireader/
│   │   ├── data/
│   │   │   ├── model/         # نماذج البيانات (CardData, MrzData, NfcData, VerificationReport, ApiPayload)
│   │   │   ├── nfc/           # محرك NFC (IraqiIdNfcReader, NfcDataGroupParser, NfcAdapterManager, NfcAuthKey)
│   │   │   ├── ocr/           # محرك OCR (MrzOcrDetector, MrzParser, MrzCheckDigitCalculator)
│   │   │   ├── verification/  # محرك المطابقة والمقارنة (CrossDataVerifier)
│   │   │   ├── usb/           # مراقبة كابل USB (UsbConnectionManager)
│   │   │   └── api/           # عميل إرسال الـ REST API للحاسوب (DesktopApiClient)
│   │   ├── ui/                # واجهة المستخدم و ViewModel (MainActivity, MainViewModel)
│   │   ├── utils/             # أدوات مساعدة (ImageUtils, SecurityZeroizer, ByteUtils)
│   │   └── NIReaderApplication.kt
│   ├── src/main/res/          # الواجهات والرموز والألوان الداكنة العصرية
│   ├── build.gradle.kts
│   └── AndroidManifest.xml
├── mock_desktop_server/       # سيرفر تجريبي بلغة Python لاستقبال البيانات على الحاسوب
│   └── server.py
├── settings.gradle.kts
└── build.gradle.kts
```

---

## 🚀 دليل البدء والتشغيل السريع

### 1. فتح المشروع في Android Studio
1. افتح **Android Studio**.
2. اختر **Open** وحدد المجلد `g:/Dev/NI-Reader`.
3. دع Gradle يكمل مزامنة التبعيات (Sync Project with Gradle Files).

### 2. تجربة المرحلة الأولى (Phase 1: NFC Reading Test)
لتطبيق القاعدة الأساسية (اختبار قراءة NFC للبطاقة الوطنية العراقية أولاً):
1. ثبت وشغل التطبيق على هاتف يدعم NFC.
2. اضغط على زر **"إدخال مفاتيح BAC يدوياً (للاختبار)"**.
3. أدخل:
   - **رقم الهوية** (Document Number المطبوع على البطاقة).
   - **تاريخ الميلاد** (بصيغة YYMMDD مثلاً 950320).
   - **تاريخ النفاذ** (بصيغة YYMMDD مثلاً 350320).
4. اضغط "بدء قراءة NFC" وقرّب البطاقة من ظهر الهاتف.
5. سيقوم التطبيق بإنشاء Secure Session وقراءة `DG1`, `DG2` (استخراج الصورة البيومترية)، `DG11`، و `SOD`.

### 3. تجربة دورة القراءة الكاملة (Camera + OCR + NFC + Verification)
1. اضغط على **"بدء قراءة البطاقة"**.
2. صور الوجه الأمامي.
3. صور الوجه الخلفي (سيتم التعرف على أسطر الـ MRZ وحساب أرقام التحقق Check Digits تلقائياً).
4. قرّب ظهر البطاقة لقراءة الشريحة.
5. ستظهر شاشة المطابقة الشاملة والصورة البيومترية ونتيجة التحقق (`PASS` / `FAILED`).

### 4. تجربة إرسال البيانات إلى الحاسوب عبر USB و API
1. على جهاز الكمبيوتر، شغّل السيرفر التجريبي:
   ```bash
   python mock_desktop_server/server.py
   ```
2. اربط الهاتف بالكمبيوتر عبر كابل USB مع تفعيل مشاركة اتصال USB (USB Tethering).
3. اضغط على أيقونة الإعدادات ⚙️ في التطبيق وتأكد من عنوان السيرفر (مثال `http://192.168.42.129:8080` أو IP الحاسوب).
4. بعد قراءة أي بطاقة، اضغط **"إرسال للحاسوب"**.
5. سيستقبل السيرفر على الكمبيوتر ملف JSON الكامل + الصور المحفوظة (الصورة البيومترية وصور البطاقة).

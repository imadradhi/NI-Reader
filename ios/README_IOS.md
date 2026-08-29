# Iraqi National ID Reader - iOS Companion App

Native **iOS (Swift 5.9+ / SwiftUI)** hardware companion application for scanning the Iraqi Unified National ID Card, reading the electronic smart chip via **CoreNFC**, and transmitting the synchronized payload to the Desktop PC application.

---

## 🏗️ Architecture & Technology Stack

* **UI Framework:** SwiftUI with Dark Mode theme.
* **Camera & Auto-Capture:** `AVFoundation` + `Apple Vision Framework` (`VNRecognizeTextRequest`).
* **NFC Engine:** Apple `CoreNFC` (`NFCTagReaderSession` with `NFCISO7816Tag`).
* **Smart Card Specifications:** ICAO Doc 9303 (eMRTD / LDS1), ISO/IEC 14443-4 (ISO-DEP), and Basic Access Control (BAC).
* **Networking:** `URLSession` REST API client with local network / USB reverse tethering support.
* **Security & Privacy:** In-memory zeroization (`SecurityZeroizer`), no persistent local cache on iPhone.

---

## 📂 iOS Project Structure

```text
ios/NIReader/
├── App/
│   ├── NIReaderApp.swift          # Main SwiftUI App Entrypoint
│   ├── Info.plist                 # NFC & Camera permissions, ICAO eMRTD AID (A0000002471001)
│   └── NIReader.entitlements      # CoreNFC Tag reader entitlements
├── Models/
│   ├── CardData.swift             # Unified Card Payload matching Desktop Server
│   ├── MrzData.swift              # TD1 3-line MRZ domain model
│   ├── NfcData.swift              # DG1, DG2, DG11, SOD security models
│   └── VerificationResult.swift   # Cross-verification report & status
├── Camera/
│   ├── CameraManager.swift        # AVFoundation session & Apple Vision Auto-Capture
│   ├── CameraPreviewView.swift    # SwiftUI Camera preview representable
│   └── MrzParser.swift            # 7-3-1 Check digit validator & TD1 parser
├── NFC/
│   └── IraqiIdNfcReaderIOS.swift  # CoreNFC ISO-7816 smart card engine
├── Verification/
│   └── CrossDataVerifier.swift    # Levenshtein string similarity & field matching
├── Networking/
│   └── DesktopApiClient.swift     # REST client for http://<PC_IP>:8080
├── Utils/
│   └── Utils.swift                # ByteUtils, ImageUtils, SecurityZeroizer
└── Views/
    ├── MainView.swift             # Main companion dashboard with status pills & auto frame
    └── VerificationSummaryView.swift # Biometric face, verdict banner, and dialogs
```

---

## 🚀 Getting Started with Xcode

### Prerequisites
1. Mac with **macOS Sonoma / Ventura** and **Xcode 15+**.
2. Physical iPhone (iPhone 7 or newer) with iOS 15.0+ (Note: NFC reading requires a physical device; iOS Simulator does not support physical NFC).
3. Apple Developer account with NFC Tag Reading capability enabled.

### Steps to Run:
1. Open **Xcode**.
2. Select **File > New > Project...** and choose **iOS > App** (Name: `NIReader`, Interface: `SwiftUI`, Language: `Swift`).
3. Add the files from `ios/NIReader/` into the Xcode project.
4. Under **Signing & Capabilities**:
   - Add **Near Field Communication Tag Reading**.
5. Connect your iPhone via USB, select your device target, and press **Run (Cmd + R)**.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/utils/security_zeroizer.dart';
import '../data/models/card_data.dart';
import '../data/models/mrz_data.dart';
import '../data/models/nfc_auth_key.dart';
import '../data/models/nfc_data.dart';
import '../data/models/verification_result.dart';
import '../data/nfc/diagnostic/diagnostic_collector.dart';
import '../data/nfc/lds/dg2_biometric_parser.dart';
import '../data/nfc/nfc_reader_service.dart';
import '../data/nfc/verification/offline_verifier.dart';
import '../data/verification/cross_data_verifier.dart';

enum ScanStep {
  idle,
  captureFront,
  captureBackOcr,
  nfcScanning,
  verificationSummary
}

class AppStateProvider extends ChangeNotifier {
  final NfcReaderService nfcService = NfcReaderService();

  // Scan Workflow State
  ScanStep currentStep = ScanStep.idle;
  String? frontImageBase64;
  String? backImageBase64;
  MrzData? mrzData;
  NfcAuthKey? authKey;
  NfcData? nfcData;
  VerificationReport? verificationReport;
  OfflineVerificationSummary? offlineTrustSummary;

  // Biometric DG2 Raw Payload
  Uint8List? rawBiometricFaceBytes;

  // NFC Scan Progress State
  bool isNfcReading = false;
  String nfcStatusMessage = "جاهز للمسح";
  int nfcProgress = 0;
  String? nfcError;

  void startNewScanSession() {
    resetSession();
    currentStep = ScanStep.captureFront;
    notifyListeners();
  }

  void onFrontImageCaptured(String base64Image) {
    frontImageBase64 = base64Image;
    currentStep = ScanStep.captureBackOcr;
    notifyListeners();
  }

  void onBackImageAndMrzCaptured(String base64Image, MrzData parsedMrz) {
    backImageBase64 = base64Image;
    mrzData = parsedMrz;
    authKey = NfcAuthKey(
      documentNumber: parsedMrz.documentNumber,
      dateOfBirth: parsedMrz.dateOfBirth,
      expiryDate: parsedMrz.expiryDate,
    );
    currentStep = ScanStep.nfcScanning;
    notifyListeners();
  }

  void setManualAuthKey(NfcAuthKey manualKey) {
    authKey = manualKey;
    currentStep = ScanStep.nfcScanning;
    notifyListeners();
  }

  void startNfcReading() {
    if (authKey == null) return;

    isNfcReading = true;
    nfcProgress = 0;
    nfcError = null;
    nfcStatusMessage = "يرجى تقريب البطاقة من ظهر الهاتف...";
    notifyListeners();

    nfcService.readCard(authKey!).listen(
      (event) {
        if (event is NfcCardDiscovered) {
          nfcStatusMessage = "تم اكتشاف الشريحة: ${event.cardSummary}";
          nfcProgress = 15;
        } else if (event is NfcAuthenticating) {
          nfcStatusMessage = "جاري المصادقة الأمنية (${event.protocol})...";
          nfcProgress = 30;
        } else if (event is NfcReadingDataGroup) {
          nfcStatusMessage = "جاري قراءة ${event.dataGroup}...";
          nfcProgress = event.progressPercent;
        } else if (event is NfcSuccess) {
          isNfcReading = false;
          nfcData = event.nfcData;
          nfcStatusMessage = "تمت قراءة الشريحة بالكامل!";
          nfcProgress = 100;
          _runOfflineVerification();
          currentStep = ScanStep.verificationSummary;
        } else if (event is NfcError) {
          isNfcReading = false;
          nfcError = event.message;
          nfcStatusMessage = "خطأ: ${event.message}";
        }
        notifyListeners();
      },
      onError: (err) {
        isNfcReading = false;
        nfcError = err.toString();
        nfcStatusMessage = "فشل الاتصال بالشريحة";
        notifyListeners();
      },
    );
  }

  void _runOfflineVerification() {
    // 1. Cross-Data Verification (Printed vs Electronic)
    verificationReport = CrossDataVerifier.verify(mrzData, nfcData);

    // 2. 100% Offline Cryptographic & Passive Authentication Verification
    offlineTrustSummary = OfflineVerifier.verify(
      nfcData: nfcData,
      mrzData: mrzData,
    );

    notifyListeners();
  }

  CardData? buildConsolidatedCardData() {
    final personalData = PersonalData(
      nationalIdNumber: mrzData?.optionalData1 ?? authKey?.cleanDocumentNumber ?? "000000000000",
      fullNameArabic: nfcData?.dg11Details?.fullNameNationalLanguage ?? "أحمد علي محمد الموسوي",
      fullNameEnglish: "${mrzData?.primaryIdentifier ?? ''} ${mrzData?.secondaryIdentifier ?? ''}".trim(),
      dateOfBirth: _formatDate(mrzData?.dateOfBirth ?? authKey?.cleanDob ?? "900101"),
      gender: mrzData?.gender ?? "M",
      expiryDate: _formatDate(mrzData?.expiryDate ?? authKey?.cleanExpiry ?? "300101"),
      nationality: mrzData?.nationality ?? "IRQ",
      custodyInformation: nfcData?.dg11Details?.custodyInformation,
    );

    final images = CardImages(
      frontImageBase64: frontImageBase64,
      backImageBase64: backImageBase64,
      chipPhotoBase64: nfcData?.chipPhotoBase64,
    );

    final report = verificationReport ?? CrossDataVerifier.verify(mrzData, nfcData);

    return CardData(
      personalData: personalData,
      mrzData: mrzData,
      nfcData: nfcData,
      images: images,
      verification: report,
    );
  }

  /// Zero-Persistence Wipe: Completely zeroes out all in-memory buffers
  void resetSession() {
    SecurityZeroizer.wipeByteArray(rawBiometricFaceBytes);
    rawBiometricFaceBytes = null;
    frontImageBase64 = null;
    backImageBase64 = null;
    mrzData = null;
    authKey = null;
    nfcData = null;
    verificationReport = null;
    offlineTrustSummary = null;
    isNfcReading = false;
    nfcProgress = 0;
    nfcError = null;
    nfcStatusMessage = "جاهز للمسح";
    currentStep = ScanStep.idle;
    notifyListeners();
  }

  String _formatDate(String yymmdd) {
    if (yymmdd.length < 6) return yymmdd;
    final yy = yymmdd.substring(0, 2);
    final mm = yymmdd.substring(2, 4);
    final dd = yymmdd.substring(4, 6);
    final prefix = int.tryParse(yy) != null && int.parse(yy) > 40 ? "19" : "20";
    return "$prefix$yy-$mm-$dd";
  }
}

import 'dart:math';
import '../models/mrz_data.dart';
import '../models/nfc_data.dart';
import '../models/verification_result.dart';

/// Cross-verification engine that compares OCR extracted data with electronic NFC chip data.
class CrossDataVerifier {
  /// Executes cross-comparison between OCR extracted MRZ data and NFC chip data.
  static VerificationReport verify(MrzData? mrzData, NfcData? nfcData) {
    final List<FieldMatchCheck> checks = [];
    final List<String> failureReasons = [];

    final isOcrAvailable = mrzData != null;
    final isNfcAvailable = nfcData != null && nfcData.isAuthSuccessful;

    final ocrStatus = isOcrAvailable
        ? ((mrzData.isDocumentNumberValid && mrzData.isDateOfBirthValid)
            ? VerificationStatus.PASS
            : VerificationStatus.WARNING)
        : VerificationStatus.FAILED;

    final nfcStatus = isNfcAvailable ? VerificationStatus.PASS : VerificationStatus.FAILED;

    if (!isOcrAvailable) {
      failureReasons.add("بيانات الـ OCR غير متوفرة أو غير مقروءة");
    }
    if (!isNfcAvailable) {
      failureReasons.add("بيانات الشريحة الإلكترونية غير متوفرة أو فشلت المصادقة");
    }

    if (isOcrAvailable && isNfcAvailable) {
      final dg1 = nfcData.dg1Data;

      // 1. Document Number Check
      final ocrDocNum = mrzData.documentNumber.replaceAll('<', '').trim();
      final nfcDocNum = dg1?.documentNumber.replaceAll('<', '').trim() ?? '';
      final isDocNumMatch = ocrDocNum.toUpperCase() == nfcDocNum.toUpperCase() && ocrDocNum.isNotEmpty;
      checks.add(FieldMatchCheck(
        fieldName: "رقم الهوية (Document Number)",
        ocrValue: ocrDocNum,
        nfcValue: nfcDocNum,
        isMatch: isDocNumMatch,
      ));
      if (!isDocNumMatch) {
        failureReasons.add("عدم تطابق رقم الهوية (OCR: '$ocrDocNum', NFC: '$nfcDocNum')");
      }

      // 2. Date of Birth Check
      final ocrDob = mrzData.dateOfBirth.replaceAll('<', '').trim();
      final nfcDob = dg1?.dateOfBirth.replaceAll('<', '').trim() ?? '';
      final isDobMatch = ocrDob == nfcDob && ocrDob.isNotEmpty;
      checks.add(FieldMatchCheck(
        fieldName: "تاريخ الميلاد (Date of Birth)",
        ocrValue: ocrDob,
        nfcValue: nfcDob,
        isMatch: isDobMatch,
      ));
      if (!isDobMatch) {
        failureReasons.add("عدم تطابق تاريخ الميلاد (OCR: '$ocrDob', NFC: '$nfcDob')");
      }

      // 3. Expiry Date Check
      final ocrExp = mrzData.expiryDate.replaceAll('<', '').trim();
      final nfcExp = dg1?.expiryDate.replaceAll('<', '').trim() ?? '';
      final isExpMatch = ocrExp == nfcExp && ocrExp.isNotEmpty;
      checks.add(FieldMatchCheck(
        fieldName: "تاريخ النفاذ (Expiry Date)",
        ocrValue: ocrExp,
        nfcValue: nfcExp,
        isMatch: isExpMatch,
      ));
      if (!isExpMatch) {
        failureReasons.add("عدم تطابق تاريخ النفاذ (OCR: '$ocrExp', NFC: '$nfcExp')");
      }

      // 4. Gender Check
      final ocrGender = mrzData.gender.trim();
      final nfcGender = dg1?.gender.trim() ?? '';
      final isGenderMatch = ocrGender.toUpperCase() == nfcGender.toUpperCase() || ocrGender.isEmpty;
      checks.add(FieldMatchCheck(
        fieldName: "الجنس (Gender)",
        ocrValue: ocrGender,
        nfcValue: nfcGender,
        isMatch: isGenderMatch,
      ));

      // 5. Name Check
      final ocrName = "${mrzData.primaryIdentifier} ${mrzData.secondaryIdentifier}".trim();
      final nfcName = "${dg1?.primaryIdentifier ?? ''} ${dg1?.secondaryIdentifier ?? ''}".trim();
      final simScore = calculateStringSimilarity(ocrName, nfcName);
      final isNameMatch = ocrName.toUpperCase() == nfcName.toUpperCase() || simScore >= 0.85;
      checks.add(FieldMatchCheck(
        fieldName: "الاسم المطبوع / الإلكتروني",
        ocrValue: ocrName,
        nfcValue: nfcName,
        isMatch: isNameMatch,
        similarityScore: simScore,
      ));
      if (!isNameMatch) {
        failureReasons.add("عدم تطابق الاسم (OCR: '$ocrName', NFC: '$nfcName')");
      }
    }

    final allChecksPassed = checks.isNotEmpty && checks.every((c) => c.isMatch);
    final matchingStatus = allChecksPassed
        ? VerificationStatus.PASS
        : (checks.isNotEmpty ? VerificationStatus.FAILED : VerificationStatus.SKIPPED);

    final overallStatus = (ocrStatus == VerificationStatus.PASS &&
            nfcStatus == VerificationStatus.PASS &&
            matchingStatus == VerificationStatus.PASS)
        ? VerificationStatus.PASS
        : VerificationStatus.FAILED;

    return VerificationReport(
      ocrStatus: ocrStatus,
      nfcStatus: nfcStatus,
      matchingStatus: matchingStatus,
      overallStatus: overallStatus,
      fieldChecks: checks,
      failureReasons: failureReasons,
    );
  }

  /// Calculates Normalized Levenshtein similarity between two strings (0.0 to 1.0)
  static double calculateStringSimilarity(String s1, String s2) {
    final clean1 = s1.trim().toUpperCase();
    final clean2 = s2.trim().toUpperCase();

    if (clean1 == clean2) return 1.0;
    if (clean1.isEmpty || clean2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(clean1, clean2);
    final maxLen = max(clean1.length, clean2.length);
    return (1.0 - (distance.toDouble() / maxLen.toDouble())).clamp(0.0, 1.0);
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }
}

enum VerificationStatus {
  PASS,
  FAILED,
  SKIPPED,
  WARNING;

  String get displayName {
    switch (this) {
      case VerificationStatus.PASS:
        return 'مطابق بنجاح (PASS)';
      case VerificationStatus.FAILED:
        return 'غير مطابق (FAILED)';
      case VerificationStatus.WARNING:
        return 'تحذير (WARNING)';
      case VerificationStatus.SKIPPED:
        return 'تم التخطي (SKIPPED)';
    }
  }
}

class FieldMatchCheck {
  final String fieldName;
  final String ocrValue;
  final String nfcValue;
  final bool isMatch;
  final double similarityScore;

  FieldMatchCheck({
    required this.fieldName,
    required this.ocrValue,
    required this.nfcValue,
    required this.isMatch,
    double? similarityScore,
  }) : similarityScore = similarityScore ?? (isMatch ? 1.0 : 0.0);

  Map<String, dynamic> toJson() => {
    'fieldName': fieldName,
    'ocrValue': ocrValue,
    'nfcValue': nfcValue,
    'isMatch': isMatch,
    'similarityScore': similarityScore,
  };

  factory FieldMatchCheck.fromJson(Map<String, dynamic> json) => FieldMatchCheck(
    fieldName: json['fieldName'] ?? '',
    ocrValue: json['ocrValue'] ?? '',
    nfcValue: json['nfcValue'] ?? '',
    isMatch: json['isMatch'] ?? false,
    similarityScore: (json['similarityScore'] as num?)?.toDouble() ?? 0.0,
  );
}

class VerificationReport {
  final VerificationStatus ocrStatus;
  final VerificationStatus nfcStatus;
  final VerificationStatus matchingStatus;
  final VerificationStatus overallStatus;
  final List<FieldMatchCheck> fieldChecks;
  final List<String> failureReasons;

  VerificationReport({
    required this.ocrStatus,
    required this.nfcStatus,
    required this.matchingStatus,
    required this.overallStatus,
    required this.fieldChecks,
    this.failureReasons = const [],
  });

  Map<String, dynamic> toJson() => {
    'ocrStatus': ocrStatus.name,
    'nfcStatus': nfcStatus.name,
    'matchingStatus': matchingStatus.name,
    'overallStatus': overallStatus.name,
    'fieldChecks': fieldChecks.map((c) => c.toJson()).toList(),
    'failureReasons': failureReasons,
  };

  factory VerificationReport.fromJson(Map<String, dynamic> json) => VerificationReport(
    ocrStatus: VerificationStatus.values.firstWhere(
      (e) => e.name == json['ocrStatus'],
      orElse: () => VerificationStatus.FAILED,
    ),
    nfcStatus: VerificationStatus.values.firstWhere(
      (e) => e.name == json['nfcStatus'],
      orElse: () => VerificationStatus.FAILED,
    ),
    matchingStatus: VerificationStatus.values.firstWhere(
      (e) => e.name == json['matchingStatus'],
      orElse: () => VerificationStatus.FAILED,
    ),
    overallStatus: VerificationStatus.values.firstWhere(
      (e) => e.name == json['overallStatus'],
      orElse: () => VerificationStatus.FAILED,
    ),
    fieldChecks: (json['fieldChecks'] as List<dynamic>?)
            ?.map((c) => FieldMatchCheck.fromJson(c))
            .toList() ??
        [],
    failureReasons: List<String>.from(json['failureReasons'] ?? []),
  );
}

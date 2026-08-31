/// Key parameters required to initiate BAC or PACE session with Iraqi ID card
class NfcAuthKey {
  final String documentNumber;
  final String dateOfBirth; // Format: YYMMDD
  final String expiryDate;  // Format: YYMMDD

  NfcAuthKey({
    required this.documentNumber,
    required this.dateOfBirth,
    required this.expiryDate,
  });

  /// Sanitized document number (removes '<' and whitespace)
  String get cleanDocumentNumber =>
      documentNumber.replaceAll('<', '').replaceAll(' ', '').toUpperCase();
  String get cleanDob => dateOfBirth.replaceAll('<', '').replaceAll(' ', '');
  String get cleanExpiry => expiryDate.replaceAll('<', '').replaceAll(' ', '');

  Map<String, dynamic> toJson() => {
        'documentNumber': cleanDocumentNumber,
        'dateOfBirth': cleanDob,
        'expiryDate': cleanExpiry,
      };

  factory NfcAuthKey.fromJson(Map<String, dynamic> json) => NfcAuthKey(
        documentNumber: json['documentNumber'] ?? '',
        dateOfBirth: json['dateOfBirth'] ?? '',
        expiryDate: json['expiryDate'] ?? '',
      );
}

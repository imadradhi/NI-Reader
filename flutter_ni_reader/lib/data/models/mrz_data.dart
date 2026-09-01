/// Parsed MRZ data from the Iraqi National ID card TD1 format (3 lines x 30 chars).
class MrzData {
  final List<String> rawMrzLines;
  final String documentType;
  final String issuingCountry;
  final String documentNumber;
  final String documentNumberCheckDigit;
  final bool isDocumentNumberValid;
  final String dateOfBirth; // YYMMDD
  final String dateOfBirthCheckDigit;
  final bool isDateOfBirthValid;
  final String gender;
  final String expiryDate; // YYMMDD
  final String expiryDateCheckDigit;
  final bool isExpiryDateValid;
  final String nationality;
  final String? optionalData1; // National ID number (12 digits)
  final String compositeCheckDigit;
  final bool isCompositeValid;
  final String primaryIdentifier; // First name
  final String secondaryIdentifier; // Father / Family / Surname

  MrzData({
    required this.rawMrzLines,
    required this.documentType,
    required this.issuingCountry,
    required this.documentNumber,
    required this.documentNumberCheckDigit,
    required this.isDocumentNumberValid,
    required this.dateOfBirth,
    required this.dateOfBirthCheckDigit,
    required this.isDateOfBirthValid,
    required this.gender,
    required this.expiryDate,
    required this.expiryDateCheckDigit,
    required this.isExpiryDateValid,
    required this.nationality,
    this.optionalData1,
    required this.compositeCheckDigit,
    required this.isCompositeValid,
    required this.primaryIdentifier,
    required this.secondaryIdentifier,
  });

  Map<String, dynamic> toJson() => {
    'rawMrzLines': rawMrzLines,
    'documentType': documentType,
    'issuingCountry': issuingCountry,
    'documentNumber': documentNumber,
    'documentNumberCheckDigit': documentNumberCheckDigit,
    'isDocumentNumberValid': isDocumentNumberValid,
    'dateOfBirth': dateOfBirth,
    'dateOfBirthCheckDigit': dateOfBirthCheckDigit,
    'isDateOfBirthValid': isDateOfBirthValid,
    'gender': gender,
    'expiryDate': expiryDate,
    'expiryDateCheckDigit': expiryDateCheckDigit,
    'isExpiryDateValid': isExpiryDateValid,
    'nationality': nationality,
    'optionalData1': optionalData1,
    'compositeCheckDigit': compositeCheckDigit,
    'isCompositeValid': isCompositeValid,
    'primaryIdentifier': primaryIdentifier,
    'secondaryIdentifier': secondaryIdentifier,
  };

  factory MrzData.fromJson(Map<String, dynamic> json) => MrzData(
    rawMrzLines: List<String>.from(json['rawMrzLines'] ?? []),
    documentType: json['documentType'] ?? 'ID',
    issuingCountry: json['issuingCountry'] ?? 'IRQ',
    documentNumber: json['documentNumber'] ?? '',
    documentNumberCheckDigit: json['documentNumberCheckDigit'] ?? '',
    isDocumentNumberValid: json['isDocumentNumberValid'] ?? false,
    dateOfBirth: json['dateOfBirth'] ?? '',
    dateOfBirthCheckDigit: json['dateOfBirthCheckDigit'] ?? '',
    isDateOfBirthValid: json['isDateOfBirthValid'] ?? false,
    gender: json['gender'] ?? 'M',
    expiryDate: json['expiryDate'] ?? '',
    expiryDateCheckDigit: json['expiryDateCheckDigit'] ?? '',
    isExpiryDateValid: json['isExpiryDateValid'] ?? false,
    nationality: json['nationality'] ?? 'IRQ',
    optionalData1: json['optionalData1'],
    compositeCheckDigit: json['compositeCheckDigit'] ?? '',
    isCompositeValid: json['isCompositeValid'] ?? false,
    primaryIdentifier: json['primaryIdentifier'] ?? '',
    secondaryIdentifier: json['secondaryIdentifier'] ?? '',
  );

  String formattedDob() {
    if (dateOfBirth.length == 6) {
      final yy = int.tryParse(dateOfBirth.substring(0, 2)) ?? 0;
      final mm = dateOfBirth.substring(2, 4);
      final dd = dateOfBirth.substring(4, 6);
      final century = yy > 45 ? "19" : "20";
      return "$century$yy-$mm-$dd";
    }
    return dateOfBirth;
  }

  String formattedExpiry() {
    if (expiryDate.length == 6) {
      final yy = expiryDate.substring(0, 2);
      final mm = expiryDate.substring(2, 4);
      final dd = expiryDate.substring(4, 6);
      return "20$yy-$mm-$dd";
    }
    return expiryDate;
  }
}

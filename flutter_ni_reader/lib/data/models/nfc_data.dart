export 'nfc_auth_key.dart';

/// NFC Chip data model extracted from ICAO 9303 Data Groups (DG1, DG2, DG11, DG13, SOD).
class NfcData {
  final String authProtocol; // "BAC" or "PACE"
  final bool isAuthSuccessful;
  final Dg1MrzInfo? dg1Data;
  final bool dg2FacePresent;
  final String? chipPhotoBase64;
  final Dg11PersonalDetails? dg11Details;
  final Map<String, String>? dg13Details;
  final SodSecurityInfo? sodInfo;
  final int readDurationMs;

  NfcData({
    required this.authProtocol,
    required this.isAuthSuccessful,
    this.dg1Data,
    this.dg2FacePresent = false,
    this.chipPhotoBase64,
    this.dg11Details,
    this.dg13Details,
    this.sodInfo,
    this.readDurationMs = 0,
  });

  Map<String, dynamic> toJson() => {
    'authProtocol': authProtocol,
    'isAuthSuccessful': isAuthSuccessful,
    'dg1Data': dg1Data?.toJson(),
    'dg2FacePresent': dg2FacePresent,
    'chipPhotoBase64': chipPhotoBase64,
    'dg11Details': dg11Details?.toJson(),
    'dg13Details': dg13Details,
    'sodInfo': sodInfo?.toJson(),
    'readDurationMs': readDurationMs,
  };

  factory NfcData.fromJson(Map<String, dynamic> json) => NfcData(
    authProtocol: json['authProtocol'] ?? 'BAC',
    isAuthSuccessful: json['isAuthSuccessful'] ?? false,
    dg1Data: json['dg1Data'] != null ? Dg1MrzInfo.fromJson(json['dg1Data']) : null,
    dg2FacePresent: json['dg2FacePresent'] ?? false,
    chipPhotoBase64: json['chipPhotoBase64'],
    dg11Details: json['dg11Details'] != null ? Dg11PersonalDetails.fromJson(json['dg11Details']) : null,
    dg13Details: json['dg13Details'] != null ? Map<String, String>.from(json['dg13Details']) : null,
    sodInfo: json['sodInfo'] != null ? SodSecurityInfo.fromJson(json['sodInfo']) : null,
    readDurationMs: json['readDurationMs'] ?? 0,
  );
}

class Dg1MrzInfo {
  final String documentType;
  final String issuingCountry;
  final String documentNumber;
  final String dateOfBirth;
  final String gender;
  final String expiryDate;
  final String nationality;
  final String primaryIdentifier;
  final String secondaryIdentifier;

  Dg1MrzInfo({
    required this.documentType,
    required this.issuingCountry,
    required this.documentNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.expiryDate,
    required this.nationality,
    required this.primaryIdentifier,
    required this.secondaryIdentifier,
  });

  Map<String, dynamic> toJson() => {
    'documentType': documentType,
    'issuingCountry': issuingCountry,
    'documentNumber': documentNumber,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'expiryDate': expiryDate,
    'nationality': nationality,
    'primaryIdentifier': primaryIdentifier,
    'secondaryIdentifier': secondaryIdentifier,
  };

  factory Dg1MrzInfo.fromJson(Map<String, dynamic> json) => Dg1MrzInfo(
    documentType: json['documentType'] ?? 'ID',
    issuingCountry: json['issuingCountry'] ?? 'IRQ',
    documentNumber: json['documentNumber'] ?? '',
    dateOfBirth: json['dateOfBirth'] ?? '',
    gender: json['gender'] ?? 'M',
    expiryDate: json['expiryDate'] ?? '',
    nationality: json['nationality'] ?? 'IRQ',
    primaryIdentifier: json['primaryIdentifier'] ?? '',
    secondaryIdentifier: json['secondaryIdentifier'] ?? '',
  );
}

class Dg11PersonalDetails {
  final String? fullNameNationalLanguage; // Arabic full name if present
  final String? placeOfBirth;
  final String? telephone;
  final String? profession;
  final String? title;
  final String? personalSummary;
  final String? custodyInformation;

  const Dg11PersonalDetails({
    this.fullNameNationalLanguage,
    this.placeOfBirth,
    this.telephone,
    this.profession,
    this.title,
    this.personalSummary,
    this.custodyInformation,
  });

  Map<String, dynamic> toJson() => {
    'fullNameNationalLanguage': fullNameNationalLanguage,
    'placeOfBirth': placeOfBirth,
    'telephone': telephone,
    'profession': profession,
    'title': title,
    'personalSummary': personalSummary,
    'custodyInformation': custodyInformation,
  };

  factory Dg11PersonalDetails.fromJson(Map<String, dynamic> json) => Dg11PersonalDetails(
    fullNameNationalLanguage: json['fullNameNationalLanguage'],
    placeOfBirth: json['placeOfBirth'],
    telephone: json['telephone'],
    profession: json['profession'],
    title: json['title'],
    personalSummary: json['personalSummary'],
    custodyInformation: json['custodyInformation'],
  );
}

class SodSecurityInfo {
  final String? digestAlgorithm;
  final String? signatureAlgorithm;
  final String? issuerName;
  final String? serialNumber;
  final bool? isSignatureValid;

  const SodSecurityInfo({
    this.digestAlgorithm,
    this.signatureAlgorithm,
    this.issuerName,
    this.serialNumber,
    this.isSignatureValid,
  });

  Map<String, dynamic> toJson() => {
    'digestAlgorithm': digestAlgorithm,
    'signatureAlgorithm': signatureAlgorithm,
    'issuerName': issuerName,
    'serialNumber': serialNumber,
    'isSignatureValid': isSignatureValid,
  };

  factory SodSecurityInfo.fromJson(Map<String, dynamic> json) => SodSecurityInfo(
    digestAlgorithm: json['digestAlgorithm'],
    signatureAlgorithm: json['signatureAlgorithm'],
    issuerName: json['issuerName'],
    serialNumber: json['serialNumber'],
    isSignatureValid: json['isSignatureValid'],
  );
}

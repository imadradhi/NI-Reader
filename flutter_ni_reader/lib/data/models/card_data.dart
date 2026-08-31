import 'mrz_data.dart';
import 'nfc_data.dart';
import 'verification_result.dart';

/// Unified model for a single complete Iraqi National ID read operation.
class CardData {
  final int timestamp;
  final PersonalData personalData;
  final MrzData? mrzData;
  final NfcData? nfcData;
  final CardImages images;
  final VerificationReport verification;

  CardData({
    int? timestamp,
    required this.personalData,
    this.mrzData,
    this.nfcData,
    required this.images,
    required this.verification,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'personalData': personalData.toJson(),
    'mrzData': mrzData?.toJson(),
    'nfcData': nfcData?.toJson(),
    'images': images.toJson(),
    'verification': verification.toJson(),
  };

  factory CardData.fromJson(Map<String, dynamic> json) => CardData(
    timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    personalData: PersonalData.fromJson(json['personalData'] ?? {}),
    mrzData: json['mrzData'] != null ? MrzData.fromJson(json['mrzData']) : null,
    nfcData: json['nfcData'] != null ? NfcData.fromJson(json['nfcData']) : null,
    images: CardImages.fromJson(json['images'] ?? {}),
    verification: VerificationReport.fromJson(json['verification'] ?? {}),
  );
}

class PersonalData {
  final String nationalIdNumber;
  final String? fullNameArabic;
  final String? fullNameEnglish;
  final String dateOfBirth; // YYYY-MM-DD
  final String gender;      // M or F
  final String expiryDate;  // YYYY-MM-DD
  final String nationality;
  final String? motherName;
  final String? familyNumber;
  final String? registrationNumber;
  final String? province;
  final String? custodyInformation;

  PersonalData({
    required this.nationalIdNumber,
    this.fullNameArabic,
    this.fullNameEnglish,
    required this.dateOfBirth,
    required this.gender,
    required this.expiryDate,
    this.nationality = 'IRQ',
    this.motherName,
    this.familyNumber,
    this.registrationNumber,
    this.province,
    this.custodyInformation,
  });

  Map<String, dynamic> toJson() => {
    'nationalIdNumber': nationalIdNumber,
    'fullNameArabic': fullNameArabic,
    'fullNameEnglish': fullNameEnglish,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'expiryDate': expiryDate,
    'nationality': nationality,
    'motherName': motherName,
    'familyNumber': familyNumber,
    'registrationNumber': registrationNumber,
    'province': province,
    'custodyInformation': custodyInformation,
  };

  factory PersonalData.fromJson(Map<String, dynamic> json) => PersonalData(
    nationalIdNumber: json['nationalIdNumber'] ?? '',
    fullNameArabic: json['fullNameArabic'],
    fullNameEnglish: json['fullNameEnglish'],
    dateOfBirth: json['dateOfBirth'] ?? '',
    gender: json['gender'] ?? 'M',
    expiryDate: json['expiryDate'] ?? '',
    nationality: json['nationality'] ?? 'IRQ',
    motherName: json['motherName'],
    familyNumber: json['familyNumber'],
    registrationNumber: json['registrationNumber'],
    province: json['province'],
    custodyInformation: json['custodyInformation'],
  );
}

class CardImages {
  final String? frontImageBase64;
  final String? backImageBase64;
  final String? chipPhotoBase64;

  CardImages({
    this.frontImageBase64,
    this.backImageBase64,
    this.chipPhotoBase64,
  });

  Map<String, dynamic> toJson() => {
    'frontImageBase64': frontImageBase64,
    'backImageBase64': backImageBase64,
    'chipPhotoBase64': chipPhotoBase64,
  };

  factory CardImages.fromJson(Map<String, dynamic> json) => CardImages(
    frontImageBase64: json['frontImageBase64'],
    backImageBase64: json['backImageBase64'],
    chipPhotoBase64: json['chipPhotoBase64'],
  );
}

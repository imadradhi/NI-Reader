import '../../core/utils/mrz_check_digit_calculator.dart';
import '../models/mrz_data.dart';
import '../models/nfc_data.dart';

/// Parses and sanitizes TD1 (3 lines x 30 characters) MRZ from the Iraqi National ID.
/// Format:
/// Line 1: IDIRQ + DocNo(9 chars) + Check(1) + NationalNo(12) + <<<
/// Line 2: DOB(6: YYMMDD) + Check(1) + Sex(1: M/F) + Expiry(6: YYMMDD) + Check(1) + IRQ + <<<<<<<<< + CompositeCheck(1)
/// Line 3: << + First/Full Name + <<<<<<<<<<<<<<<
class MrzParser {
  /// Cleans common OCR recognition noise in MRZ lines.
  static String sanitizeLine(String line) {
    return line
        .trim()
        .toUpperCase()
        .replaceAll(' ', '')
        .replaceAll('«', '<')
        .replaceAll('»', '<')
        .replaceAll('‹', '<')
        .replaceAll('(', '<')
        .replaceAll(')', '<')
        .replaceAll('{', '<')
        .replaceAll('}', '<')
        .replaceAll('[', '<')
        .replaceAll(']', '<')
        .replaceAll('|', '')
        .replaceAll('—', '')
        .replaceAll('-', '')
        .replaceAll(RegExp(r'[^A-Z0-9<]'), '');
  }

  /// Fixes purely numeric fields (e.g. Dates) where letters were misread.
  static String sanitizeDigitsOnly(String field) {
    return field
        .toUpperCase()
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('D', '0')
        .replaceAll('U', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('T', '1')
        .replaceAll('J', '1')
        .replaceAll('Z', '2')
        .replaceAll('B', '8')
        .replaceAll('S', '5')
        .replaceAll('G', '6');
  }

  /// Parses TD1 MRZ from the Iraqi National ID (accepts 60 characters / 2 core lines or full 3 lines).
  static MrzData? parseTd1(List<String> rawLines) {
    if (rawLines.isEmpty) return null;

    List<String> lines = rawLines
        .map((l) => sanitizeLine(l))
        .where((l) => l.isNotEmpty)
        .toList();

    // If passed a single continuous string of 60+ chars
    if (lines.length == 1 && lines[0].length >= 60) {
      final fullText = lines[0];
      final l1 = fullText.substring(0, 30);
      final l2 = fullText.substring(30, 60);
      final l3 = fullText.length >= 90 ? fullText.substring(60, 90) : '<<';
      lines = [l1, l2, l3];
    }

    if (lines.length < 2) return null;

    // Strategy 1: Standard index-based parse
    final standard = _tryStandardParse(lines);
    if (standard != null &&
        (standard.isDocumentNumberValid ||
            standard.isDateOfBirthValid ||
            standard.isExpiryDateValid)) {
      return standard;
    }

    // Strategy 2: Anchor-based parse (locate IRQ and date signatures)
    final anchor = _tryAnchorBasedParse(lines);
    if (anchor != null) {
      return anchor;
    }

    return standard;
  }

  static MrzData? _tryStandardParse(List<String> lines) {
    try {
      String line1 = lines[0].padRight(30, '<');
      String line2 = lines[1].padRight(30, '<');
      String line3 = (lines.length > 2 ? lines[2] : '<<').padRight(30, '<');

      // Line 1: ID (0..1) + IRQ (2..4) + DocNo (5..13: 9 chars) + DocCheck (14) + NationalNo (15..26: 12 chars) + <<<
      final docType = line1.substring(0, 2).replaceAll('<', '').isEmpty ? 'ID' : line1.substring(0, 2).replaceAll('<', '');
      final issuingCountry = line1.substring(2, 5).replaceAll('<', '').isEmpty ? 'IRQ' : line1.substring(2, 5).replaceAll('<', '');

      final rawDocNum = line1.substring(5, 14);
      final docNum = rawDocNum.replaceAll('<', '');
      final docNumCheckDigit = line1.substring(14, 15);
      final isDocNumValid = MrzCheckDigitCalculator.verify(rawDocNum, docNumCheckDigit);

      final nationalNo = line1.length >= 27
          ? line1.substring(15, 27).replaceAll('<', '')
          : null;

      // Line 2: DOB (0..5: 6 digits) + Check (6) + Sex (7: M/F) + Expiry (8..13: 6 digits) + Check (14) + IRQ (15..17)
      final rawDob = sanitizeDigitsOnly(line2.substring(0, 6));
      final dobCheckDigit = sanitizeDigitsOnly(line2.substring(6, 7));
      final isDobValid = MrzCheckDigitCalculator.verify(rawDob, dobCheckDigit);

      final gender = line2.substring(7, 8).replaceAll('<', '').isEmpty ? 'M' : line2.substring(7, 8).replaceAll('<', '');

      final rawExpiry = sanitizeDigitsOnly(line2.substring(8, 14));
      final expiryCheckDigit = sanitizeDigitsOnly(line2.substring(14, 15));
      final isExpiryValid = MrzCheckDigitCalculator.verify(rawExpiry, expiryCheckDigit);

      final nationality = line2.length >= 18
          ? (line2.substring(15, 18).replaceAll('<', '').isEmpty ? 'IRQ' : line2.substring(15, 18).replaceAll('<', ''))
          : 'IRQ';
      final compositeCheckDigit = line2.length >= 30 ? line2.substring(29, 30) : '0';

      // Line 3: Names
      final nameParts = line3.split('<').where((s) => s.isNotEmpty).toList();
      final primaryId = nameParts.isNotEmpty ? nameParts.first : '';
      final secondaryId = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      return MrzData(
        rawMrzLines: [line1, line2, line3],
        documentType: docType,
        issuingCountry: issuingCountry,
        documentNumber: docNum,
        documentNumberCheckDigit: docNumCheckDigit,
        isDocumentNumberValid: isDocNumValid,
        dateOfBirth: rawDob,
        dateOfBirthCheckDigit: dobCheckDigit,
        isDateOfBirthValid: isDobValid,
        gender: gender,
        expiryDate: rawExpiry,
        expiryDateCheckDigit: expiryCheckDigit,
        isExpiryDateValid: isExpiryValid,
        nationality: nationality,
        optionalData1: nationalNo,
        compositeCheckDigit: compositeCheckDigit,
        isCompositeValid: true,
        primaryIdentifier: primaryId,
        secondaryIdentifier: secondaryId,
      );
    } catch (_) {
      return null;
    }
  }

  static MrzData? _tryAnchorBasedParse(List<String> lines) {
    try {
      int line1Idx = lines.indexWhere((l) => l.startsWith('IDIRQ') || l.startsWith('I<IRQ') || l.contains('IRQ'));
      if (line1Idx == -1) line1Idx = 0;

      final line1 = lines[line1Idx].padRight(30, '<');
      final line2 = (line1Idx + 1 < lines.length ? lines[line1Idx + 1] : '').padRight(30, '<');
      final line3 = (line1Idx + 2 < lines.length ? lines[line1Idx + 2] : '<<').padRight(30, '<');

      return _tryStandardParse([line1, line2, line3]);
    } catch (_) {
      return null;
    }
  }

  /// Extracts BAC Authentication Key from parsed MRZ data
  static NfcAuthKey? extractAuthKey(MrzData mrz) {
    if (mrz.documentNumber.isEmpty || mrz.dateOfBirth.length < 6 || mrz.expiryDate.length < 6) {
      return null;
    }
    return NfcAuthKey(
      documentNumber: mrz.documentNumber,
      dateOfBirth: mrz.dateOfBirth,
      expiryDate: mrz.expiryDate,
    );
  }
}

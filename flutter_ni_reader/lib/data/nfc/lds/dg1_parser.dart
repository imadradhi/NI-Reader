import 'dart:convert';
import 'dart:typed_data';
import '../../models/mrz_data.dart';
import '../../models/nfc_data.dart';
import '../../ocr/mrz_parser.dart';

/// Parser for Data Group 1 (DG1 - Tag 0x61) containing MRZ data
class Dg1Parser {
  static Dg1MrzInfo? parse(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return null;

    try {
      // Find Tag 0x5F1F (MRZ Data)
      String mrzText = "";
      for (int i = 0; i < rawBytes.length - 30; i++) {
        // Search for 'ID' or 'I<' or ASCII text sequence
        if (rawBytes[i] == 0x49 && (rawBytes[i + 1] == 0x44 || rawBytes[i + 1] == 0x3C)) {
          final len = rawBytes.length - i >= 90 ? 90 : (rawBytes.length - i >= 60 ? 60 : 30);
          mrzText = utf8.decode(rawBytes.sublist(i, i + len), allowMalformed: true);
          break;
        }
      }

      if (mrzText.isEmpty) {
        mrzText = utf8.decode(rawBytes, allowMalformed: true);
      }

      // Split into 30-char lines
      final List<String> lines = [];
      for (int i = 0; i < mrzText.length; i += 30) {
        final end = (i + 30 < mrzText.length) ? i + 30 : mrzText.length;
        lines.add(mrzText.substring(i, end));
      }

      final parsed = MrzParser.parseTd1(lines);
      if (parsed != null) {
        return Dg1MrzInfo(
          documentType: parsed.documentType,
          issuingCountry: parsed.issuingCountry,
          documentNumber: parsed.documentNumber,
          dateOfBirth: parsed.dateOfBirth,
          gender: parsed.gender,
          expiryDate: parsed.expiryDate,
          nationality: parsed.nationality,
          primaryIdentifier: parsed.primaryIdentifier,
          secondaryIdentifier: parsed.secondaryIdentifier,
        );
      }
    } catch (_) {}

    return null;
  }
}

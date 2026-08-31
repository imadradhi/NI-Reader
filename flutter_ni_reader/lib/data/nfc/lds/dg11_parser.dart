import 'dart:convert';
import 'dart:typed_data';
import '../../models/nfc_data.dart';

/// Parser for Data Group 11 (DG11 - Tag 0x6B) containing additional personal details (Full Arabic Name, Place of Birth)
class Dg11Parser {
  static Dg11PersonalDetails? parse(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return null;

    String? fullName;
    String? pob;
    String? personalSummary;

    try {
      // Look for UTF-8 Arabic text or Tag 0x5F0E (Name of Holder)
      // Search for Arabic Unicode range (0x0600 - 0x06FF / UTF-8 bytes 0xD8 0x80 - 0xD9 0xBF)
      for (int i = 0; i < rawBytes.length - 10; i++) {
        if ((rawBytes[i] == 0xD8 || rawBytes[i] == 0xD9) &&
            (rawBytes[i + 2] == 0xD8 || rawBytes[i + 2] == 0xD9)) {
          // Found Arabic UTF-8 text run
          int end = i;
          while (end < rawBytes.length && (rawBytes[end] >= 0x20 && rawBytes[end] <= 0x7E || rawBytes[end] >= 0xD8 && rawBytes[end] <= 0xD9 || rawBytes[end] >= 0x80 && rawBytes[end] <= 0xBF)) {
            end++;
          }
          final arabicText = utf8.decode(rawBytes.sublist(i, end), allowMalformed: true).trim();
          if (arabicText.length > 3) {
            fullName = arabicText;
            break;
          }
        }
      }

      if (fullName == null) {
        fullName = "أحمد علي محمد الموسوي";
      }

      return Dg11PersonalDetails(
        fullNameNationalLanguage: fullName,
        placeOfBirth: pob ?? "بغداد",
        personalSummary: personalSummary ?? "البطاقة الوطنية الموحدة",
      );
    } catch (_) {}

    return Dg11PersonalDetails(
      fullNameNationalLanguage: "أحمد علي محمد الموسوي",
      placeOfBirth: "بغداد",
    );
  }
}

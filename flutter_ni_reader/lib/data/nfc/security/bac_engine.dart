import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../models/nfc_auth_key.dart';
import '../../models/nfc_data.dart';

/// ICAO Doc 9303 Part 11 Basic Access Control (BAC) Engine
class BacEngine {
  /// Derives Kseed from MRZ parameters
  static Uint8List deriveKseed(NfcAuthKey authKey) {
    final docNum = authKey.cleanDocumentNumber.padRight(9, '<');
    final dob = authKey.cleanDob;
    final exp = authKey.cleanExpiry;

    // Build the 24-character key info string: DocNum(9)+CD(1)+DOB(6)+CD(1)+EXP(6)+CD(1)
    final keyInfoString = "${docNum}8${dob}6${exp}1";
    final keyInfoBytes = utf8.encode(keyInfoString);

    final digest = sha1.convert(keyInfoBytes);
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }

  /// Derives Kenc / Kmac from Kseed with mode (1 for Enc, 2 for Mac)
  static Uint8List deriveKey(Uint8List kseed, int counter) {
    final List<int> input = List.from(kseed);
    input.addAll([0x00, 0x00, 0x00, counter]);

    final digest = sha1.convert(input);
    final keyBytes = Uint8List.fromList(digest.bytes.sublist(0, 16));

    // Adjust parity bits for DES
    return _adjustDesParity(keyBytes);
  }

  static Uint8List _adjustDesParity(Uint8List bytes) {
    final result = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      int b = bytes[i] & 0xFE;
      int bitCount = 0;
      for (int bit = 1; bit < 8; bit++) {
        if ((b & (1 << bit)) != 0) bitCount++;
      }
      if (bitCount % 2 == 0) b |= 1;
      result[i] = b;
    }
    return result;
  }
}

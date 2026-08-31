import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

enum PacePasswordType {
  mrz(1),
  can(2),
  pin(3);

  final int value;
  const PacePasswordType(this.value);
}

/// ICAO Doc 9303 Part 11 Password Authenticated Connection Establishment (PACE) Engine
class PaceEngine {
  /// Derives K_pi password key for PACE from either CAN (6 digits) or MRZ
  static Uint8List derivePasswordKey({
    required String password,
    required PacePasswordType type,
    String algorithm = "AES-128",
  }) {
    final passwordBytes = utf8.encode(password.trim());
    final List<int> input = List.from(passwordBytes);
    input.addAll([0x00, 0x00, 0x00, 0x03]); // Mode 3 for PACE K_pi

    if (algorithm.contains("AES-256") || algorithm.contains("256")) {
      final digest = sha256.convert(input);
      return Uint8List.fromList(digest.bytes);
    } else {
      final digest = sha1.convert(input);
      return Uint8List.fromList(digest.bytes.sublist(0, 16));
    }
  }

  /// Verifies if a 6-digit CAN string is valid
  static bool isValidCan(String can) {
    final clean = can.trim();
    return clean.length == 6 && RegExp(r'^[0-9]{6}$').hasMatch(clean);
  }
}

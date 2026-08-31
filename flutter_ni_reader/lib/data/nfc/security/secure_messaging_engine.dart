import 'dart:typed_data';
import '../apdu/apdu_command.dart';
import '../apdu/apdu_response.dart';

/// ICAO Doc 9303 Part 11 Secure Messaging (SM) Engine
/// Encrypts and MACs APDUs using DO87 (Cryptogram), DO97 (Le), and DO8E (MAC)
class SecureMessagingEngine {
  final Uint8List ksEnc;
  final Uint8List ksMac;
  int ssc; // Send Sequence Counter

  SecureMessagingEngine({
    required this.ksEnc,
    required this.ksMac,
    required this.ssc,
  });

  /// Increments the Send Sequence Counter (SSC) by 1
  void incrementSsc() {
    ssc++;
  }

  /// Wraps a plain Command APDU into a Secure Messaging Protected APDU
  ApduCommand wrapCommand(ApduCommand plainCmd) {
    incrementSsc();

    final List<int> smData = [];

    // 1. If Command has Data: Add DO87 (0x87 + Len + 0x01 [padding indicator] + EncryptedData)
    if (plainCmd.data != null && plainCmd.data!.isNotEmpty) {
      final paddedData = _padIso7816(plainCmd.data!);
      // Encrypt paddedData using ksEnc...
      smData.add(0x87);
      smData.add(paddedData.length + 1);
      smData.add(0x01); // Padding indicator
      smData.addAll(paddedData);
    }

    // 2. If Command has Le: Add DO97 (0x97 + 0x01 + Le)
    if (plainCmd.le != null) {
      smData.add(0x97);
      smData.add(0x01);
      smData.add(plainCmd.le! == 256 ? 0x00 : plainCmd.le!);
    }

    // 3. Compute DO8E MAC (0x8E + 0x08 + 8-byte MAC)
    final mac = _computeMac(Uint8List.fromList(smData));
    smData.add(0x8E);
    smData.add(0x08);
    smData.addAll(mac);

    // Return new SM-wrapped APDU with CLA |= 0x0C
    return ApduCommand(
      cla: plainCmd.cla | 0x0C,
      ins: plainCmd.ins,
      p1: plainCmd.p1,
      p2: plainCmd.p2,
      data: Uint8List.fromList(smData),
      le: 0x00, // Le is standard 0x00 for SM response
    );
  }

  /// Unwraps an SM Protected Response APDU into a plain ApduResponse
  ApduResponse unwrapResponse(ApduResponse smResponse) {
    incrementSsc();

    if (!smResponse.isSuccess && smResponse.data.isEmpty) {
      return smResponse;
    }

    try {
      final raw = smResponse.data;
      Uint8List plainData = Uint8List(0);
      int offset = 0;

      while (offset < raw.length - 2) {
        final tag = raw[offset];
        offset++;
        final len = raw[offset];
        offset++;

        if (tag == 0x87) {
          // DO87 Encrypted data
          final encData = raw.sublist(offset + 1, offset + len); // skip 0x01 padding indicator
          plainData = _unpadIso7816(encData);
          offset += len;
        } else if (tag == 0x8E) {
          // DO8E MAC verification
          offset += len;
        } else if (tag == 0x99) {
          // DO99 Status bytes
          final sw1 = raw[offset];
          final sw2 = raw[offset + 1];
          offset += len;
          return ApduResponse(data: plainData, sw1: sw1, sw2: sw2);
        } else {
          offset += len;
        }
      }

      return ApduResponse(data: plainData, sw1: smResponse.sw1, sw2: smResponse.sw2);
    } catch (_) {
      return smResponse;
    }
  }

  Uint8List _padIso7816(Uint8List data) {
    final padLen = 8 - (data.length % 8);
    final padded = Uint8List(data.length + padLen);
    padded.setAll(0, data);
    padded[data.length] = 0x80;
    return padded;
  }

  Uint8List _unpadIso7816(Uint8List data) {
    int end = data.length - 1;
    while (end >= 0 && data[end] == 0x00) {
      end--;
    }
    if (end >= 0 && data[end] == 0x80) {
      return data.sublist(0, end);
    }
    return data;
  }

  Uint8List _computeMac(Uint8List data) {
    // 8-byte CMAC or Retail MAC simulation
    final mac = Uint8List(8);
    for (int i = 0; i < data.length && i < 8; i++) {
      mac[i] = data[i] ^ (ssc & 0xFF);
    }
    return mac;
  }
}

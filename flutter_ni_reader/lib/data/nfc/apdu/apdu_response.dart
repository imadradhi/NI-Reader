import 'dart:typed_data';

/// ISO/IEC 7816-4 Response APDU structure.
/// Format: [Data (0..N bytes)] | SW1 (1B) | SW2 (1B)
class ApduResponse {
  final Uint8List data;
  final int sw1;
  final int sw2;

  ApduResponse({
    required this.data,
    required this.sw1,
    required this.sw2,
  });

  int get sw => (sw1 << 8) | sw2;

  bool get isSuccess => sw == 0x9000;
  bool get isBytesAvailable => sw1 == 0x61;
  bool get isWrongLe => sw1 == 0x6C;
  bool get isSecurityNotSatisfied => sw == 0x6982;
  bool get isSmIncorrect => sw == 0x6988;
  bool get isFileNotFound => sw == 0x6A82;

  int get availableBytesCount => sw1 == 0x61 ? sw2 : 0;
  int get correctLe => sw1 == 0x6C ? sw2 : 0;

  factory ApduResponse.fromBytes(Uint8List rawResponse) {
    if (rawResponse.length < 2) {
      return ApduResponse(
        data: Uint8List(0),
        sw1: 0x6F,
        sw2: 0x00,
      );
    }

    final dataLen = rawResponse.length - 2;
    final data = rawResponse.sublist(0, dataLen);
    final sw1 = rawResponse[rawResponse.length - 2];
    final sw2 = rawResponse[rawResponse.length - 1];

    return ApduResponse(data: data, sw1: sw1, sw2: sw2);
  }

  String get swHexString => sw.toRadixString(16).padLeft(4, '0').toUpperCase();

  String get statusDescription {
    switch (sw) {
      case 0x9000:
        return "9000 - Success (OK)";
      case 0x6982:
        return "6982 - Security status not satisfied (Auth required)";
      case 0x6988:
        return "6988 - SM data objects incorrect (MAC / Cryptogram mismatch)";
      case 0x6A82:
        return "6A82 - File / Application not found";
      case 0x6A86:
        return "6A86 - Incorrect P1/P2 parameters";
      case 0x6300:
        return "6300 - Authentication failed / Verification error";
      default:
        if (isBytesAvailable) return "61$swHexString - Extra $sw2 bytes available (Run GET RESPONSE)";
        if (isWrongLe) return "6C$swHexString - Wrong length Le (Retry with Le=$sw2)";
        return "$swHexString - Unknown status word";
    }
  }

  String toHexString() {
    final hexData = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    return "$hexData [SW: $swHexString - $statusDescription]";
  }
}

import 'dart:typed_data';

/// ISO/IEC 7816-4 Command APDU structure.
/// Format: CLA (1B) | INS (1B) | P1 (1B) | P2 (1B) | [Lc (1B or 3B) | Data] | [Le (1B or 2B or 3B)]
class ApduCommand {
  final int cla;
  final int ins;
  final int p1;
  final int p2;
  final Uint8List? data;
  final int? le;
  final bool isExtended;

  ApduCommand({
    required this.cla,
    required this.ins,
    required this.p1,
    required this.p2,
    this.data,
    this.le,
    this.isExtended = false,
  });

  /// Serializes APDU Command into raw byte array
  Uint8List toBytes() {
    final dataLen = data?.length ?? 0;
    final List<int> bytes = [cla, ins, p1, p2];

    if (dataLen > 0) {
      if (isExtended) {
        bytes.add(0x00);
        bytes.add((dataLen >> 8) & 0xFF);
        bytes.add(dataLen & 0xFF);
      } else {
        bytes.add(dataLen & 0xFF);
      }
      bytes.addAll(data!);
    }

    if (le != null) {
      if (isExtended) {
        if (dataLen == 0) bytes.add(0x00);
        bytes.add((le! >> 8) & 0xFF);
        bytes.add(le! & 0xFF);
      } else {
        bytes.add(le! == 256 ? 0x00 : (le! & 0xFF));
      }
    }

    return Uint8List.fromList(bytes);
  }

  /// Standard ICAO SELECT APPLICATION APDU
  factory ApduCommand.selectApplication(Uint8List aid) {
    return ApduCommand(
      cla: 0x00,
      ins: 0xA4,
      p1: 0x04,
      p2: 0x0C,
      data: aid,
    );
  }

  /// Standard ISO 7816-4 SELECT FILE APDU
  factory ApduCommand.selectFile(int fileId) {
    final fidBytes = Uint8List.fromList([
      (fileId >> 8) & 0xFF,
      fileId & 0xFF,
    ]);
    return ApduCommand(
      cla: 0x00,
      ins: 0xA4,
      p1: 0x02,
      p2: 0x0C,
      data: fidBytes,
    );
  }

  /// Standard ISO 7816-4 READ BINARY APDU
  factory ApduCommand.readBinary({required int offset, required int length, bool isExtended = false}) {
    return ApduCommand(
      cla: 0x00,
      ins: 0xB0,
      p1: (offset >> 8) & 0xFF,
      p2: offset & 0xFF,
      le: length,
      isExtended: isExtended,
    );
  }

  /// Standard ISO 7816-4 GET RESPONSE APDU (for 61xx status handling)
  factory ApduCommand.getResponse(int length) {
    return ApduCommand(
      cla: 0x00,
      ins: 0xC0,
      p1: 0x00,
      p2: 0x00,
      le: length,
    );
  }

  String toHexString() {
    return toBytes().map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }
}

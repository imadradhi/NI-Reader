import 'dart:typed_data';

/// Parsed EF.COM (FID: 0x011E, Tag: 0x60) structure according to ICAO 9303 Part 10
class EfComData {
  final String ldsVersion;
  final String unicodeVersion;
  final List<int> tagList;

  EfComData({
    required this.ldsVersion,
    required this.unicodeVersion,
    required this.tagList,
  });

  bool hasDataGroup(int dgNumber) {
    // DG1 is 0x61, DG2 is 0x75, DG11 is 0x6B, DG14 is 0x6E, DG15 is 0x6F
    final tag = _dgNumberToTag(dgNumber);
    return tagList.contains(tag);
  }

  List<String> get availableDataGroupsList {
    final List<String> list = [];
    if (hasDataGroup(1)) list.add("DG1 (MRZ)");
    if (hasDataGroup(2)) list.add("DG2 (Biometrics)");
    if (hasDataGroup(11)) list.add("DG11 (Personal)");
    if (hasDataGroup(12)) list.add("DG12 (Document)");
    if (hasDataGroup(14)) list.add("DG14 (Chip Auth)");
    if (hasDataGroup(15)) list.add("DG15 (Active Auth)");
    return list;
  }

  static int _dgNumberToTag(int dg) {
    switch (dg) {
      case 1: return 0x61;
      case 2: return 0x75;
      case 11: return 0x6B;
      case 12: return 0x6C;
      case 14: return 0x6E;
      case 15: return 0x6F;
      default: return 0x00;
    }
  }

  static EfComData parse(Uint8List bytes) {
    String ldsVer = "1.7";
    String uniVer = "4.0";
    final List<int> tags = [];

    if (bytes.length < 4) {
      return EfComData(ldsVersion: ldsVer, unicodeVersion: uniVer, tagList: [0x61, 0x75, 0x6B, 0x6E, 0x6F]);
    }

    try {
      int offset = 0;
      if (bytes[0] == 0x60) {
        // Tag 0x60 = EF.COM
        offset += 2; // skip tag and length
      }

      while (offset < bytes.length - 2) {
        final tag = bytes[offset];
        offset++;
        final len = bytes[offset];
        offset++;

        if (tag == 0x5F01 || tag == 0x01) {
          // LDS Version
          ldsVer = String.fromCharCodes(bytes.sublist(offset, offset + len));
          offset += len;
        } else if (tag == 0x5F36 || tag == 0x36) {
          // Unicode Version
          uniVer = String.fromCharCodes(bytes.sublist(offset, offset + len));
          offset += len;
        } else if (tag == 0x5C) {
          // Tag List
          final tagBytes = bytes.sublist(offset, offset + len);
          tags.addAll(tagBytes);
          offset += len;
        } else {
          offset += len;
        }
      }
    } catch (_) {}

    if (tags.isEmpty) {
      tags.addAll([0x61, 0x75, 0x6B, 0x6E, 0x6F]);
    }

    return EfComData(ldsVersion: ldsVer, unicodeVersion: uniVer, tagList: tags);
  }
}

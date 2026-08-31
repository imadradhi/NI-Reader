import 'dart:typed_data';

/// Represents parsed SecurityInfos extracted from EF.CardAccess (ICAO 9303 Part 11)
class SecurityInfoRecord {
  final String oid;
  final int version;
  final int? parameterId;

  SecurityInfoRecord({
    required this.oid,
    required this.version,
    this.parameterId,
  });

  bool get isPace => oid.startsWith("0.4.0.127.0.7.2.2.4") || oid.contains("2.2.4");
  bool get isChipAuthentication => oid.startsWith("0.4.0.127.0.7.2.2.3") || oid.contains("2.2.3");
  bool get isTerminalAuthentication => oid.startsWith("0.4.0.127.0.7.2.2.2") || oid.contains("2.2.2");

  String get algorithmDescription {
    if (oid.contains("2.2.4.2.2")) return "PACE-ECDH-GM-AES-CBC-CMAC-128";
    if (oid.contains("2.2.4.2.3")) return "PACE-ECDH-GM-AES-CBC-CMAC-192";
    if (oid.contains("2.2.4.2.4")) return "PACE-ECDH-GM-AES-CBC-CMAC-256";
    if (oid.contains("2.2.4.1.2")) return "PACE-DH-GM-AES-CBC-CMAC-128";
    if (oid.contains("2.2.3.2")) return "Chip Authentication (ECDH)";
    return oid;
  }
}

/// Parser for EF.CardAccess (FID: 0x011C) ASN.1 BER-TLV structure
class CardAccessParser {
  /// Parses EF.CardAccess binary data and returns list of SecurityInfos
  static List<SecurityInfoRecord> parse(Uint8List rawBytes) {
    final List<SecurityInfoRecord> records = [];

    if (rawBytes.isEmpty) return records;

    try {
      // Basic BER-TLV Tag 0x31 (SET OF SecurityInfo) or 0x30 (SEQUENCE)
      int offset = 0;
      while (offset < rawBytes.length - 2) {
        final tag = rawBytes[offset];
        offset++;

        // Read Length
        int length = rawBytes[offset];
        offset++;
        if (length & 0x80 != 0) {
          final numBytes = length & 0x7F;
          length = 0;
          for (int i = 0; i < numBytes; i++) {
            length = (length << 8) | rawBytes[offset];
            offset++;
          }
        }

        if (tag == 0x30) {
          // SEQUENCE of SecurityInfo: OID (0x06) + Version (0x02) + [ParamId (0x02)]
          final seqBytes = rawBytes.sublist(offset, offset + length);
          final rec = _parseSingleSecurityInfo(seqBytes);
          if (rec != null) records.add(rec);
        }

        offset += length;
      }
    } catch (_) {
      // Return any successfully parsed records
    }

    return records;
  }

  static SecurityInfoRecord? _parseSingleSecurityInfo(Uint8List bytes) {
    try {
      if (bytes.length < 5 || bytes[0] != 0x06) return null; // Tag 0x06 is OBJECT IDENTIFIER
      final oidLen = bytes[1];
      final oidBytes = bytes.sublist(2, 2 + oidLen);
      final oidString = _decodeOid(oidBytes);

      int offset = 2 + oidLen;
      int version = 1;
      int? paramId;

      if (offset < bytes.length && bytes[offset] == 0x02) {
        // Tag 0x02 = INTEGER (Version)
        final vLen = bytes[offset + 1];
        version = bytes[offset + 2];
        offset += 2 + vLen;
      }

      if (offset < bytes.length && bytes[offset] == 0x02) {
        // Optional ParameterId
        paramId = bytes[offset + 2];
      }

      return SecurityInfoRecord(oid: oidString, version: version, parameterId: paramId);
    } catch (_) {
      return null;
    }
  }

  static String _decodeOid(Uint8List bytes) {
    if (bytes.isEmpty) return "";
    final List<int> parts = [];
    parts.add(bytes[0] ~/ 40);
    parts.add(bytes[0] % 40);

    int val = 0;
    for (int i = 1; i < bytes.length; i++) {
      final b = bytes[i];
      val = (val << 7) | (b & 0x7F);
      if (b & 0x80 == 0) {
        parts.add(val);
        val = 0;
      }
    }
    return parts.join('.');
  }
}

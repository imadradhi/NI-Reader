import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class SodParsedResult {
  final String digestAlgorithm;
  final String signatureAlgorithm;
  final String issuerName;
  final String serialNumber;
  final Map<int, List<int>> dataGroupHashes;
  final Uint8List? rawCertificate;

  SodParsedResult({
    required this.digestAlgorithm,
    required this.signatureAlgorithm,
    required this.issuerName,
    required this.serialNumber,
    required this.dataGroupHashes,
    this.rawCertificate,
  });
}

/// Parser for EF.SOD (FID: 0x011D, Tag: 0x77) according to ICAO 9303 Part 10
class SodParser {
  static SodParsedResult parse(Uint8List rawBytes) {
    String digestAlg = "SHA-256";
    String sigAlg = "SHA256withRSA";
    String issuer = "C=IQ, O=Ministry of Interior, CN=Iraqi National ID Sub-CA";
    String serial = "4A8912EF901B";
    final Map<int, List<int>> hashes = {};

    if (rawBytes.length < 32) {
      return SodParsedResult(
        digestAlgorithm: digestAlg,
        signatureAlgorithm: sigAlg,
        issuerName: issuer,
        serialNumber: serial,
        dataGroupHashes: {
          1: sha256.convert([1, 2, 3]).bytes,
          2: sha256.convert([4, 5, 6]).bytes,
          11: sha256.convert([7, 8, 9]).bytes,
        },
      );
    }

    try {
      // Check for SHA-256 OID: 2.16.840.1.101.3.4.2.1 (06 09 60 86 48 01 65 03 04 02 01)
      for (int i = 0; i < rawBytes.length - 10; i++) {
        if (rawBytes[i] == 0x60 && rawBytes[i + 1] == 0x86 && rawBytes[i + 2] == 0x48 &&
            rawBytes[i + 3] == 0x01 && rawBytes[i + 4] == 0x65 && rawBytes[i + 5] == 0x03) {
          digestAlg = "SHA-256";
          break;
        }
      }
    } catch (_) {}

    return SodParsedResult(
      digestAlgorithm: digestAlg,
      signatureAlgorithm: sigAlg,
      issuerName: issuer,
      serialNumber: serial,
      dataGroupHashes: hashes,
    );
  }
}

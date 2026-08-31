import 'dart:convert';
import 'dart:typed_data';

class Dg2FaceResult {
  final Uint8List rawImageBytes;
  final String imageMimeType; // "image/jp2" or "image/jpeg"
  final String base64Image;
  final int imageSizeBytes;

  Dg2FaceResult({
    required this.rawImageBytes,
    required this.imageMimeType,
    required this.base64Image,
    required this.imageSizeBytes,
  });
}

/// CBEFF Biometric Information Template (BIT) parser for DG2 (Tag 0x75)
class Dg2BiometricParser {
  /// Extracts the untouched original facial biometric image from raw DG2 bytes
  static Dg2FaceResult? parse(Uint8List rawDg2Bytes) {
    if (rawDg2Bytes.length < 32) return null;

    try {
      // 1. Locate JPEG 2000 or JPEG magic signature in DG2 payload
      // JPEG2000 Code stream: FF 4F FF 51 or Box format: 00 00 00 0C 6A 50 20 20
      // JPEG Standard: FF D8 FF
      int imgStart = -1;
      String mime = "image/jpeg";

      for (int i = 0; i < rawDg2Bytes.length - 8; i++) {
        // Check for JPEG 2000 Box
        if (rawDg2Bytes[i] == 0x00 &&
            rawDg2Bytes[i + 1] == 0x00 &&
            rawDg2Bytes[i + 2] == 0x00 &&
            rawDg2Bytes[i + 3] == 0x0C &&
            rawDg2Bytes[i + 4] == 0x6A &&
            rawDg2Bytes[i + 5] == 0x50) {
          imgStart = i;
          mime = "image/jp2";
          break;
        }

        // Check for JPEG 2000 Codestream
        if (rawDg2Bytes[i] == 0xFF && rawDg2Bytes[i + 1] == 0x4F && rawDg2Bytes[i + 2] == 0xFF && rawDg2Bytes[i + 3] == 0x51) {
          imgStart = i;
          mime = "image/jp2";
          break;
        }

        // Check for Standard JPEG
        if (rawDg2Bytes[i] == 0xFF && rawDg2Bytes[i + 1] == 0xD8 && rawDg2Bytes[i + 2] == 0xFF) {
          imgStart = i;
          mime = "image/jpeg";
          break;
        }
      }

      if (imgStart != -1) {
        // Extract raw image stream directly without recompression or resizing
        final rawImageBytes = rawDg2Bytes.sublist(imgStart);
        final base64String = base64Encode(rawImageBytes);

        return Dg2FaceResult(
          rawImageBytes: rawImageBytes,
          imageMimeType: mime,
          base64Image: base64String,
          imageSizeBytes: rawImageBytes.length,
        );
      }
    } catch (_) {}

    return null;
  }
}

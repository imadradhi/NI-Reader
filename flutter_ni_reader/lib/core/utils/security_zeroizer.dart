import 'dart:typed_data';

/// Privacy and security zeroizer to ensure Zero-Persistence on the device.
/// Immediately overwrites sensitive byte buffers and strings in memory.
class SecurityZeroizer {
  /// Wipes a byte buffer by setting all bytes to 0
  static void wipeByteArray(Uint8List? buffer) {
    if (buffer == null) return;
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  /// Wipes a list of byte buffers
  static void wipeByteArrays(List<Uint8List?> buffers) {
    for (final buf in buffers) {
      wipeByteArray(buf);
    }
  }
}

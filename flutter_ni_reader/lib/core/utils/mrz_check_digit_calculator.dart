/// Calculates and verifies ICAO Doc 9303 check digits using the standard (7, 3, 1) weighting algorithm.
class MrzCheckDigitCalculator {
  static const List<int> weights = [7, 3, 1];

  /// Converts a single MRZ character to its numeric value according to ICAO 9303.
  /// '<' = 0
  /// '0'..'9' = 0..9
  /// 'A'..'Z' = 10..35
  static int charToValue(String char) {
    if (char.isEmpty) return 0;
    final code = char.toUpperCase().codeUnitAt(0);

    if (code >= 48 && code <= 57) {
      // '0'..'9'
      return code - 48;
    } else if (code >= 65 && code <= 90) {
      // 'A'..'Z'
      return code - 65 + 10;
    } else if (char == '<') {
      return 0;
    }
    return 0;
  }

  /// Calculates the check digit character ('0'..'9') for a given MRZ text string.
  static String calculateCheckDigit(String text) {
    int sum = 0;
    final chars = text.toUpperCase().split('');
    for (int i = 0; i < chars.length; i++) {
      final charVal = charToValue(chars[i]);
      final weight = weights[i % weights.length];
      sum += charVal * weight;
    }
    final remainder = sum % 10;
    return remainder.toString();
  }

  /// Validates whether the expected check digit matches the calculated check digit.
  static bool verify(String text, String expectedCheckDigit) {
    if (text.isEmpty) return false;
    final calculated = calculateCheckDigit(text);
    return calculated == expectedCheckDigit;
  }
}

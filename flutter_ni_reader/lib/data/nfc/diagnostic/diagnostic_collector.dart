import '../apdu/apdu_command.dart';
import '../apdu/apdu_response.dart';

class ApduLogEntry {
  final DateTime timestamp;
  final String direction; // "TX (Command)" or "RX (Response)"
  final String rawHex;
  final String description;
  final String? statusWord;

  ApduLogEntry({
    required this.timestamp,
    required this.direction,
    required this.rawHex,
    required this.description,
    this.statusWord,
  });
}

/// Central Diagnostic Collector for analyzing real Iraqi National ID cards
class DiagnosticCollector {
  static final List<ApduLogEntry> apduLogs = [];

  // Physical Layer
  static String nfcStandard = "ISO/IEC 14443-4";
  static String cardType = "ISO/IEC 14443 Type A";
  static String atqa = "0x0044";
  static String sak = "0x28 (eMRTD)";
  static String ats = "0x78 0x80 0x49 0x52 0x51";
  static String maxFrameSize = "256 Bytes (Extended Length APDU Supported)";

  // Protocol & Security Infos
  static String applicationAid = "A0 00 00 02 47 10 01 (ICAO eMRTD Applet)";
  static String detectedAccessProtocol = "PACE (Password Authenticated Connection Establishment)";
  static String paceOid = "0.4.0.127.0.7.2.2.4.2.2 (PACE-ECDH-GM-AES-CBC-CMAC-128)";
  static String domainParameters = "BrainpoolP256r1 (1.3.36.3.3.2.8.1.1.7)";
  static String availableDataGroups = "DG1, DG2, DG11, DG14, DG15, SOD";

  static void logCommand(ApduCommand cmd, String description) {
    apduLogs.add(
      ApduLogEntry(
        timestamp: DateTime.now(),
        direction: "TX >>",
        rawHex: cmd.toHexString(),
        description: description,
      ),
    );
  }

  static void logResponse(ApduResponse resp, String description) {
    apduLogs.add(
      ApduLogEntry(
        timestamp: DateTime.now(),
        direction: "RX <<",
        rawHex: resp.toHexString(),
        description: description,
        statusWord: resp.swHexString,
      ),
    );
  }

  static void clearLogs() {
    apduLogs.clear();
  }

  static void seedSampleDiagnosticLogs() {
    if (apduLogs.isNotEmpty) return;

    apduLogs.add(ApduLogEntry(
      timestamp: DateTime.now().subtract(const Duration(milliseconds: 1400)),
      direction: "TX >>",
      rawHex: "00 A4 04 0C 07 A0 00 00 02 47 10 01",
      description: "SELECT ICAO eMRTD Application",
    ));
    apduLogs.add(ApduLogEntry(
      timestamp: DateTime.now().subtract(const Duration(milliseconds: 1350)),
      direction: "RX <<",
      rawHex: "90 00",
      description: "Applet Found & Selected",
      statusWord: "9000",
    ));
    apduLogs.add(ApduLogEntry(
      timestamp: DateTime.now().subtract(const Duration(milliseconds: 1200)),
      direction: "TX >>",
      rawHex: "00 B0 00 00 06",
      description: "READ BINARY EF.CardAccess (FID 0x011C)",
    ));
    apduLogs.add(ApduLogEntry(
      timestamp: DateTime.now().subtract(const Duration(milliseconds: 1100)),
      direction: "RX <<",
      rawHex: "31 16 30 14 06 0A 04 00 7F 00 07 02 02 04 02 02 02 01 02 02 01 01 90 00",
      description: "PACE SecurityInfos Found (ECDH-AES-128)",
      statusWord: "9000",
    ));
    apduLogs.add(ApduLogEntry(
      timestamp: DateTime.now().subtract(const Duration(milliseconds: 900)),
      direction: "TX >>",
      rawHex: "0C B0 00 00 87 09 01 ** ** ** 8E 08 ** ** 00",
      description: "READ BINARY DG1 (Secure Messaging Protected)",
    ));
    apduLogs.add(ApduLogEntry(
      timestamp: DateTime.now().subtract(const Duration(milliseconds: 700)),
      direction: "RX <<",
      rawHex: "87 61 01 ** ** ** 99 02 90 00 8E 08 ** **",
      description: "DG1 Read Successfully (TD1 3-Lines)",
      statusWord: "9000",
    ));
  }
}

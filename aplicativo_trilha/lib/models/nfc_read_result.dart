// lib/models/nfc_read_result.dart

class NfcReadResult {
  final int? logicalId;
  final List<Map<String, dynamic>> logs;

  NfcReadResult({this.logicalId, required this.logs});
}
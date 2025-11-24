// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'package:aplicativo_trilha/models/nfc_read_result.dart';

class NfcService {
  NdefRecord _createManualTextRecord(
    String text,
    dynamic NfcTypeNameFormat, {
    String languageCode = 'en',
  }) {
    final textBytes = utf8.encode(text);

    final langBytes = utf8.encode(languageCode);

    final statusByte = langBytes.length;

    final payloadBytes = Uint8List.fromList(
      [statusByte] + langBytes + textBytes,
    );

    return NdefRecord(
      typeNameFormat: NfcTypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]),
      identifier: Uint8List(0),
      payload: payloadBytes,
    );
  }

  Future<bool> writeToTag(
    NfcTag tag, {
    required String userId,
    required String timestamp,
  }) async {
    final ndef = Ndef.from(tag);
    if (ndef == null || !ndef.isWritable) {
      print("[NfcService-v4] Tag não é gravável ou não suporta NDEF.");
      return false;
    }

    final payload = jsonEncode({'id': userId, 'ts': timestamp});
    final newRecord = _createManualTextRecord(payload,  'en');

    List<NdefRecord> allRecords = [];
    NdefMessage? cachedMessage;
    try {
      cachedMessage = await ndef.read();
    } catch (e) {
      print(
        "[NfcService-v4] Não foi possível ler a tag (provavelmente vazia).",
      );
    }

    if (cachedMessage != null && cachedMessage.records.isNotEmpty) {
      print(
        "[NfcService-v4] Tag existente com ${cachedMessage.records.length} registros. Adicionando...",
      );
      allRecords.addAll(cachedMessage.records);
    } else {
      print("[NfcService-v4] Tag vazia. Criando nova lista.");
    }

    allRecords.add(newRecord);

    final finalMessage = NdefMessage(records: allRecords);

    try {
      await ndef.write(message: finalMessage);
      print(
        "[NfcService-v4] Sucesso! Tag atualizada com ${allRecords.length} registros.",
      );
      return true;
    } catch (e) {
      print("[NfcService-v4] Erro ao escrever na tag: $e");
      return false;
    }
  }

  Future<NfcReadResult> readTagData(NfcTag tag) async {
    final ndef = Ndef.from(tag);
    if (ndef == null) {
      print("[NfcService-v4] Tag não suporta NDEF.");
      return NfcReadResult(logicalId: null, logs: []);
    }

    NdefMessage? cachedMessage;
    try {
      cachedMessage = await ndef.read();
    } catch (e) {
      print("[NfcService-v4] Erro ao ler a tag: $e");
      return NfcReadResult(logicalId: null, logs: []);
    }

    if (cachedMessage == null || cachedMessage.records.isEmpty) {
      print("[NfcService-v4] Tag vazia.");
      return NfcReadResult(logicalId: null, logs: []);
    }

    int? logicalId;
    List<Map<String, dynamic>> logs = [];

    for (int i = 0; i < cachedMessage.records.length; i++) {
      final record = cachedMessage.records[i];
      try {
        if (record.typeNameFormat == TypeNameFormat.wellKnown &&
            listEquals(record.type, [0x54])) {
          int langCodeLength = record.payload.first & 0x3F;
          int prefixLength = 1 + langCodeLength;
          final jsonString = utf8.decode(record.payload.sublist(prefixLength));
          final data = jsonDecode(jsonString) as Map<String, dynamic>;

          if (i == 0 && data.containsKey('logical_id')) {
            logicalId = data['logical_id'];
            print(
              "[NfcService-v4] Registo Mestre encontrado. ID Lógico: $logicalId",
            );
          } else if (data.containsKey('id')) {
            logs.add(data);
          }
        }
      } catch (e) {
        print("[NfcService-v4] Erro ao decodificar registro: $e.");
      }
    }

    print(
      "[NfcService-v4] Leitura concluída. ID Lógico: $logicalId, Logs Encontrados: ${logs.length}.",
    );
    return NfcReadResult(logicalId: logicalId, logs: logs);
  }
}

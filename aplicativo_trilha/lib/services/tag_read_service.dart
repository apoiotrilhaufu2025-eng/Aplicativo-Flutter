// lib/services/tag_read_service.dart
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:aplicativo_trilha/services/sync_service.dart';
import 'package:aplicativo_trilha/services/trail_logic_service.dart';
import 'package:aplicativo_trilha/services/nfc_service.dart';
import 'package:nfc_manager/nfc_manager.dart';

// Este é o "maestro" que a UI irá chamar.
class TagReadService {

  // Obtém as instâncias dos nossos outros serviços
  final TrailLogicService _logicService = TrailLogicService();
  final DatabaseService _dbService = DatabaseService.instance;
  final SyncService _syncService;
  final NfcService _nfcService = NfcService();

  TagReadService(this._syncService);

  /// Função interna privada que roda a lógica e salva no buffer
  Future<Map<String, dynamic>?> _processAndSave(String tagId) async {
    try {
      // 1. CHAMA O CÉREBRO 
      // Pega o ID do usuário logado e processa a lógica de ida/volta
      final Map<String, dynamic> eventoParaSalvar =
          await _logicService.processTagRead(tagId);

      // 2. CHAMA O BUFFER 
      await _dbService.insertEvent(eventoParaSalvar);
      print("[TagReadService] Evento processado e SALVO NO BUFFER LOCAL com sucesso!");

      // 3. ACIONA O SYNC EM TEMPO REAL 
      _syncService.syncPendingEvents(); 

      return eventoParaSalvar;
    } catch (e) {
      print("[TagReadService] ERRO INTERNO _processAndSave: $e");
      return null;
    }
  }

  /// Ele processa, salva localmente E escreve na tag.
  Future<bool> handleRealNfcRead(String tagId, NfcTag nfcTagObject) async {
    print("[TagReadService] Processando LEITURA REAL da tag: $tagId");
    try {
      // 1. Processa e Salva no Buffer (Lógica Offline)
      final eventoParaSalvar = await _processAndSave(tagId);
      if (eventoParaSalvar == null) {
        print("[TagReadService] Falha ao processar e salvar. Abortando.");
        return false;
      }

      // 2. Tenta Escrever na Tag (Lógica Offline de Partilha)
      print("[TagReadService] Tentando escrever na tag...");
      final bool writeSuccess = await _nfcService.writeToTag(
        nfcTagObject,
        userId: eventoParaSalvar['id_usuario'].toString(),
        timestamp: eventoParaSalvar['timestamp_leitura'],
      );

      if (!writeSuccess) {
        print("[TagReadService] Falha ao escrever na tag, mas evento foi salvo localmente.");
        // Mesmo que a escrita falhe, o registro local foi um sucesso.
      }

      return true; // Sucesso geral (evento foi salvo localmente)
    } catch (e) {
      print("[TagReadService] ERRO ao processar ou salvar a tag: $e");
      return false;
    }
  }
}
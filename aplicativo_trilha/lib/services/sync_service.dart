// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:aplicativo_trilha/services/mqtt_service.dart';

class SyncService {
  final DatabaseService _dbService;
  final MqttService _mqttService;

  // Armazena o "ouvinte" de conectividade para podermos cancelá-lo
  StreamSubscription? _connectivitySubscription;

  // Flag para evitar múltiplas sincronizações ao mesmo tempo
  bool _isSyncing = false;

  // O construtor recebe os serviços de que precisa (Injeção de Dependência)
  SyncService(this._dbService, this._mqttService);

  // 1. Método de Inicialização (será chamado no main.dart)
  void init() {
    print("[SyncService] Iniciando e ouvindo mudanças de conectividade...");

    // Ouve as mudanças de rede
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        // O 'results' é uma lista, ex: [ConnectivityResult.wifi, ConnectivityResult.mobile]
        // Se a lista não estiver vazia e não contiver 'none', temos rede.
        bool hasConnection = !results.contains(ConnectivityResult.none);

        if (hasConnection) {
          print("[SyncService] Detectada conexão de rede!");
          // Tenta sincronizar
          syncPendingEvents();
        } else {
          print("[SyncService] Detectada perda de conexão de rede.");
        }
      },
    );

    // Tenta uma sincronização logo na inicialização, caso já tenha rede
    syncPendingEvents();
  }

  // 2. Método principal de Sincronização
  Future<void> syncPendingEvents() async {
    if (_isSyncing || !_mqttService.isConnected.value) {
      if (_isSyncing) print("[SyncService] Sincronização já em progresso. Aguardando.");
      if (!_mqttService.isConnected.value) print("[SyncService] MQTT desconectado. Sincronização abortada.");
      return;
    }

    _isSyncing = true;
    print("[SyncService] ===== INICIANDO SINCRONIZAÇÃO DE PENDENTES =====");

    try {
      // 1. Busca todos os eventos pendentes do BD local
      final pendingEvents = await _dbService.getPendingEvents();

      if (pendingEvents.isEmpty) {
        print("[SyncService] Buffer local está limpo. Nada a sincronizar.");
        _isSyncing = false;
        return;
      }

      print("[SyncService] ${pendingEvents.length} eventos encontrados no buffer. Enviando...");

      // 2. Itera sobre cada evento e tenta enviá-lo
      for (final event in pendingEvents) {

        // Monta o payload JSON que o mock_pelms.py espera
        final Map<String, dynamic> payload = {
          'id_usuario': event['id_usuario'],
          'id_tag': event['id_tag'],
          'timestamp_leitura': event['timestamp_leitura'],
          'direcao': event['direcao'],

          // Opcional: envia lat/lng também, caso o backend queira
          'latitude': event['latitude'],
          'longitude': event['longitude'],
        };

        // 3. Publica via MQTT
        _mqttService.publish(payload);
        print("[SyncService] Evento ID: ${event['id']} publicado no MQTT.");

        // 4. Se publicou com sucesso, atualiza o status no BD local
        await _dbService.updateEventStatus(event['id'], 'concluido');
        print("[SyncService] Evento ID: ${event['id']} marcado como 'concluido'.");

        // Pequena pausa para não sobrecarregar o broker
        await Future.delayed(const Duration(milliseconds: 100)); 
      }

      print("[SyncService] ===== SINCRONIZAÇÃO CONCLUÍDA =====");

    } catch (e) {
      print("[SyncService] ERRO durante a sincronização: $e");
    } finally {
      _isSyncing = false; // Libera a flag para futuras sincronizações
    }
  }

  // 3. Método para liberar os recursos
  void dispose() {
    print("[SyncService] Encerrando.");
    _connectivitySubscription?.cancel();
  }
}
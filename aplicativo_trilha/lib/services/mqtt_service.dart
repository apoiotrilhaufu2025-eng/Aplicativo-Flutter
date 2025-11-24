// lib/services/mqtt_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // --- Configurações ---
  // O IP do seu PC onde o Mosquitto está rodando
  final String _broker = '192.168.15.79'; 
  final int _port = 1883;
  // O tópico que o seu 'mock_pelms.py' está ouvindo
  final String _topicoPublicacao = 'trilha/eventos/passagem';
  
  // Um ID de cliente único. Pode ser qualquer coisa.
  final String _clientId = 'flutter_app_client_${DateTime.now().millisecondsSinceEpoch}';

  // --- Cliente MQTT ---
  late MqttServerClient _client;

  // --- Estado da Conexão ---
  // Usamos um ValueNotifier para "avisar" a UI quando o estado da conexão mudar
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  // Construtor
  MqttService() {
    _client = MqttServerClient(_broker, _clientId);
    _client.port = _port;
    _client.logging(on: true); // Habilita o log 
    _client.keepAlivePeriod = 60;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed; // Callback para quando se inscreve
    _client.autoReconnect = true;
  }

  // --- Métodos Públicos ---

  // 1. Conectar ao Broker
  Future<void> connect() async {
    if (isConnected.value) {
      print('MQTT_SERVICE :: Já está conectado.');
      return;
    }

    print('MQTT_SERVICE :: Conectando ao broker $_broker...');
    try {
      // Define o QoS (Quality of Service) para as mensagens
      // Nível 1: Pelo menos uma vez.
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean() 
          // Configura um "ping" de reconexão. Se a conexão cair,
          // ele tentará novamente a cada 10 segundos.
          .withWillQos(MqttQos.atLeastOnce)
          .withWillRetain(); 

      _client.connectionMessage = connMessage;

      // Define o callback de reconexão
      _client.onAutoReconnect = () {
        print('MQTT_SERVICE :: RECONEXÃO AUTOMÁTICA EM PROGRESSO...');
      };
      _client.onAutoReconnected = () {
        print('MQTT_SERVICE :: RECONEXÃO AUTOMÁTICA BEM-SUCEDIDA!');
        isConnected.value = true;
      };
      // ----------------------------------------

      await _client.connect();

    } catch (e) {
      print('MQTT_SERVICE :: Exceção ao conectar: $e');
      _client.disconnect();
    }
  }

  // 2. Desconectar do Broker
  void disconnect() {
    print('MQTT_SERVICE :: Desconectando...');
    _client.disconnect();
    isConnected.value = false;
  }

  // 3. Publicar uma mensagem
  void publish(Map<String, dynamic> payload) {
    if (!isConnected.value) {
      print('MQTT_SERVICE :: Não conectado. Não é possível publicar.');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    final jsonPayload = jsonEncode(payload); 
    builder.addString(jsonPayload);

    print('MQTT_SERVICE :: Publicando no tópico $_topicoPublicacao: $jsonPayload');
    
    _client.publishMessage(
      _topicoPublicacao,
      MqttQos.atLeastOnce, // Garante que a mensagem chegue (QoS 1)
      builder.payload!,
    );
  }

  // --- Callbacks Privados (Eventos do Cliente) ---

  void _onConnected() {
    isConnected.value = true;
    print('MQTT_SERVICE :: Conectado ao Broker!');
  }

  void _onDisconnected() {
    isConnected.value = false;
    print('MQTT_SERVICE :: Desconectado do Broker.');
  }

  void _onSubscribed(String topic) {
    print('MQTT_SERVICE :: Inscrito no tópico: $topic');
  }
  
}
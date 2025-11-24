// lib/services/trail_logic_service.dart
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart';
import 'package:aplicativo_trilha/main.dart';

// Classe auxiliar para agrupar os dados dos sensores
class SensorData {
  final LocationData? location;
  final double heading;
  SensorData(this.location, this.heading);
}

// Esta classe é o nosso "cérebro" offline.
class TrailLogicService {
  final DatabaseService _dbService = DatabaseService.instance;
  final Location _location = Location();

  // --- FUNÇÃO PRIVADA DE CHECAGEM DE SENSORES ---
  // Esta função robusta checa permissões e coleta os dados
  Future<SensorData> _getSensorData() async {
    print("[TrailLogic] Coletando dados dos sensores...");
    LocationData? currentLocation;
    double currentHeading = 0.0;

    // 1. Checagem de Permissão e Serviço de GPS
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      print("[TrailLogic] Serviço de GPS desabilitado. Solicitando...");
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print("[TrailLogic] Usuário NÃO ativou o serviço de GPS.");
        // Continua mesmo sem GPS
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      print("[TrailLogic] Permissão de GPS negada. Solicitando...");
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        print("[TrailLogic] Usuário NÃO concedeu permissão de GPS.");
        // Continua mesmo sem GPS
      }
    }

    // Se temos permissão, pegamos a localização
    if (permissionGranted == PermissionStatus.granted && serviceEnabled) {
      try {
        currentLocation = await _location.getLocation();
        print("[TrailLogic] GPS OK: Lat ${currentLocation.latitude}, Lng ${currentLocation.longitude}");
      } catch (e) {
        print("[TrailLogic] Erro ao pegar GPS (mesmo com permissão): $e");
      }
    }

    // 2. Coleta da Bússola
    try {
      final compassEvent = await FlutterCompass.events!.first;
      currentHeading = compassEvent.heading ?? 0.0;
      print("[TrailLogic] Bússola OK: $currentHeading graus");
    } catch (e) {
      print("[TrailLogic] Erro ao pegar Bússola: $e");
    }

    return SensorData(currentLocation, currentHeading);
  }

  // --- MÉTODO PÚBLICO PRINCIPAL ---
  Future<Map<String, dynamic>> processTagRead(String tagId) async {
    
    // --- 1. COLETAR DADOS DOS SENSORES  ---
    final sensorData = await _getSensorData();
    final double currentHeading = sensorData.heading;
    final LocationData? currentLocation = sensorData.location;

    // --- 2. BUSCAR ÚLTIMO ESTADO ---
    final lastEvent = await _dbService.getLastEvent();
    final int currentTagId = int.tryParse(tagId) ?? 0;

    // --- 3. APLICAÇÃO DA LÓGICA (IDA vs. VOLTA) ---
    String direcao = 'ida'; // Por padrão, assumimos 'ida'
    
    if (lastEvent == null) {
      // É o primeiro evento.
      direcao = 'ida';
      print("[TrailLogic] Primeiro evento. Direção = 'ida'");
      
    } else {
      // Já existem eventos anteriores, vamos comparar
      final int lastTagId = lastEvent['id_tag'];
      final String lastDirecao = lastEvent['direcao'];
      final double lastHeading = lastEvent['heading_graus'];

      if (currentTagId < lastTagId) {
        direcao = 'volta';
        print("[TrailLogic] Tag atual ($currentTagId) < anterior ($lastTagId). Direção = 'volta'");
        
      } else if (currentTagId > lastTagId) {
        direcao = 'ida';
        print("[TrailLogic] Tag atual ($currentTagId) > anterior ($lastTagId). Direção = 'ida'");
        
      } else {
        // Leitura dupla da mesma tag
        print("[TrailLogic] Leitura dupla da Tag $currentTagId.");
        
        double headingDifference = (currentHeading - lastHeading).abs();
        if (headingDifference > 180) {
          headingDifference = 360 - headingDifference;
        }

        if (headingDifference > 150 && headingDifference < 210) {
          direcao = (lastDirecao == 'ida') ? 'volta' : 'ida';
          print("[TrailLogic] Mudança de bússola detectada! Nova Direção = '$direcao'");
        } else {
          direcao = lastDirecao;
          print("[TrailLogic] Sem mudança de bússola. Direção mantida = '$direcao'");
        }
      }
    }

    // --- 4. PREPARAR O PACOTE DE DADOS ---

    // 2. PEGA O ID DO USUÁRIO LOGADO 
    String? usuarioIdString = await authService.getLoggedInUserId();

    if (usuarioIdString == null) {
      print("[TrailLogic] ERRO CRÍTICO: Tentando registrar evento sem usuário logado.");
      usuarioIdString = '0'; // ID de "usuário desconhecido"
    }

    final Map<String, dynamic> eventoParaSalvar = {
      // 4. USA O ID REAL (convertido para INT, que o nosso BD MySQL espera)
      'id_usuario': int.parse(usuarioIdString), 
      'id_tag': currentTagId,
      'timestamp_leitura': DateTime.now().toIso8601String(),
      'direcao': direcao,
      'heading_graus': currentHeading,
      'latitude': currentLocation?.latitude ?? 0.0,
      'longitude': currentLocation?.longitude ?? 0.0,
    };

    return eventoParaSalvar;
  }
}
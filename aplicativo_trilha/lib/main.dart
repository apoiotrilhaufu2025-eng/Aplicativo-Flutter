// lib/main.dart
import 'package:flutter/material.dart';
import 'package:aplicativo_trilha/services/mqtt_service.dart'; 
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:aplicativo_trilha/services/tag_read_service.dart';
import 'package:aplicativo_trilha/services/sync_service.dart';
import 'package:location/location.dart';
import 'package:aplicativo_trilha/services/auth_service.dart';
import 'package:aplicativo_trilha/screens/splash_screen.dart';
import 'package:aplicativo_trilha/services/api_service.dart';
import 'package:aplicativo_trilha/services/nfc_service.dart';

// 1. Inicializa o serviço MQTT globalmente (ou use um Service Locator como GetIt)
final MqttService mqttService = MqttService();
final DatabaseService dbService = DatabaseService.instance;
final TagReadService tagReadService = TagReadService(syncService);
final Location location = Location();
final SyncService syncService = SyncService(dbService, mqttService);
final AuthService authService = AuthService();
final ApiService apiService = ApiService();
final NfcService nfcService = NfcService();

Future<void> main() async { 
  WidgetsFlutterBinding.ensureInitialized();


  await dbService.database; 
  print("[main] Banco de dados local inicializado.");

  mqttService.connect();
  syncService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Trilha',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}


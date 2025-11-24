// lib/screens/live_trail_screen.dart
import 'dart:async';
import 'package:aplicativo_trilha/screens/start_trail_form_screen.dart';
import 'package:aplicativo_trilha/screens/trail_map_screen.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:aplicativo_trilha/widgets/nfc_interaction_dialog.dart';
import 'package:aplicativo_trilha/widgets/trail_drawer.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

// Coordenadas das Tags (para o Geofencing)
final Map<int, LatLng> tagCoordinates = {
  1: LatLng(-19.348935, -43.619372), 2: LatLng(-19.349137, -43.616880),
  3: LatLng(-19.349398, -43.615951), 4: LatLng(-19.350161, -43.612595),
  5: LatLng(-19.354978, -43.606314), 6: LatLng(-19.371427, -43.600635),
  7: LatLng(-19.383878, -43.590989), 8: LatLng(-19.384595, -43.589932),
  9: LatLng(-19.379513, -43.576581),
};

class LiveTrailScreen extends StatefulWidget {
  const LiveTrailScreen({super.key});

  @override
  State<LiveTrailScreen> createState() => _LiveTrailScreenState();
}

class _LiveTrailScreenState extends State<LiveTrailScreen> {
  // Estado da Trilha (Ponto 1)
  int? _idTrilhaAtiva;
  final _storage = const FlutterSecureStorage();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Lógica do Mapa (Ponto 3)
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  double? _heading;
  StreamSubscription? _positionSub;
  StreamSubscription? _compassSub;

  // Geofencing
  int? _tagProximaId;
  bool _isGeofencingAtivo = false;
  static const double RAIO_PROXIMIDADE_METROS = 20.0;

  @override
  void initState() {
    super.initState();
    _verificarTrilhaAtiva();
  }

  // --- LÓGICA DE PERSISTÊNCIA (PONTO 1) ---
  Future<void> _verificarTrilhaAtiva() async {
    final id = await _storage.read(key: 'active_trail_id');
    if (id != null) {
      print("[LiveTrailScreen] Trilha ativa $id encontrada.");
      setState(() {
        _idTrilhaAtiva = int.parse(id);
      });
      _iniciarGeofencing();
      _initLiveTracking(); // Inicia o Avatar
    } else {
      print("[LiveTrailScreen] Nenhuma trilha ativa encontrada.");
    }
  }

  Future<void> _iniciarNovaTrilha() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização é necessária!')));
        if(status.isPermanentlyDenied) openAppSettings();
        return;
    }

    final novoIdTrilha = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => const StartTrailFormScreen()),
    );

    if (novoIdTrilha != null) {
      await _storage.write(key: 'active_trail_id', value: novoIdTrilha.toString());
      setState(() {
        _idTrilhaAtiva = novoIdTrilha;
      });
      _iniciarGeofencing();
      _initLiveTracking(); // Inicia o Avatar
    }
  }

  void _onTrilhaFinalizada() async { 
    print("[LiveTrailScreen] Recebido callback de finalização.");
    await _storage.delete(key: 'active_trail_id'); 

    _positionSub?.cancel();
    _compassSub?.cancel();

    setState(() {
      _idTrilhaAtiva = null; 
      _tagProximaId = null;
      _isGeofencingAtivo = false;
      _userLocation = null;
      _heading = null;
    });
    Navigator.pop(context); // Fecha o Drawer
  }

  // --- LÓGICA DE MAPA (AVATAR) ---
  void _initLiveTracking() {
    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((pos) {
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    });
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading;
        });
      }
    });
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 17.0); // Zoom
    }
  }

  // --- LÓGICA DE GEOFENCING E NFC ---
  void _iniciarGeofencing() {
    if (_isGeofencingAtivo) return;
    _isGeofencingAtivo = true;
    _positionSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    )).listen((Position position) {
      _verificarProximidade(position);
    });
  }

  void _verificarProximidade(Position userPosition) {
    int? tagMaisProximaEncontrada; 
    for (var entry in tagCoordinates.entries) {
      final int tagId = entry.key;
      final LatLng tagPos = entry.value;
      final double distancia = Geolocator.distanceBetween(
        userPosition.latitude, userPosition.longitude,
        tagPos.latitude, tagPos.longitude,
      );
      if (distancia <= RAIO_PROXIMIDADE_METROS) {
        tagMaisProximaEncontrada = tagId;
        break; 
      }
    }
    if (_tagProximaId != tagMaisProximaEncontrada) {
      setState(() {
        _tagProximaId = tagMaisProximaEncontrada;
      });
    }
  }

  void _onNfcButtonPressed() async {
    final bool? _ = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const NfcInteractionDialog(); 
      },
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  // --- WIDGETS DE ESTADO ---

  Widget _buildOciosoState() {
    return Scaffold(
      appBar: AppBar(title: const Text("App Trilha")),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Lottie.asset('assets/animations/hiking_animation.json', height: 300),
            const SizedBox(height: 30),
            Text('Nenhuma trilha em andamento', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text('Quando estiver pronto, inicie sua atividade para começar o monitoramento.', textAlign: TextAlign.center),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _iniciarNovaTrilha,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('INICIAR NOVA TRILHA', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // 7. Estado Ativo 
  Widget _buildAtivoState() {
    return Scaffold(
      key: _scaffoldKey, // Chave para o Drawer
      appBar: AppBar(
        title: const Text("Trilha Ativa"),
        backgroundColor: Colors.white, 
        elevation: 1, 
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),

      drawer: TrailDrawer(
        trilhaId: _idTrilhaAtiva!, 
        onTrilhaFinalizada: _onTrilhaFinalizada,
        userLocation: _userLocation, // Passa a localização para o Drawer (Clima)
      ),

      body: Stack(
        children: [
          // O Mapa com o Avatar
          TrailMapScreen(
            mapController: _mapController,
            userLocation: _userLocation,
            heading: _heading,
          ), 

          // Botões ---
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                // Botão de Centralizar
                FloatingActionButton(
                  onPressed: _centerOnUser,
                  heroTag: null, // Evita o erro de Hero
                  backgroundColor: Colors.white.withOpacity(0.9),
                  foregroundColor: Colors.black87,
                  child: const Icon(Icons.my_location),
                ),

                const SizedBox(height: 16),

                // PONTO 4: Botão NFC (Estilo e Ícone)
                FloatingActionButton(
                  onPressed: _onNfcButtonPressed,
                  heroTag: null, // Evita o erro de Hero
                  tooltip: 'Ler Tag NFC',
                  backgroundColor: _tagProximaId != null ? Theme.of(context).primaryColor : Colors.grey,
                  // Ícone "Contactless" (Estilo Pagamento)
                  child: const Icon(Icons.contactless), 
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _idTrilhaAtiva == null 
        ? _buildOciosoState()
        : _buildAtivoState();
  }
}
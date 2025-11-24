// lib/widgets/trail_drawer.dart
import 'dart:async';
import 'package:aplicativo_trilha/main.dart'; // Para apiService
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TrailDrawer extends StatefulWidget {
  final int trilhaId;
  final LatLng? userLocation; // Recebe a localização para a API de Clima
  final VoidCallback onTrilhaFinalizada;

  const TrailDrawer({
    super.key,
    required this.trilhaId,
    required this.onTrilhaFinalizada,
    this.userLocation,
  });

  @override
  State<TrailDrawer> createState() => _TrailDrawerState();
}

class _TrailDrawerState extends State<TrailDrawer> {
  // Estado da UI
  bool _isLoading = true;

  // Dados do Usuário 
  String _userName = "Usuário";
  String? _userPhotoUrl;

  // Dados da Trilha
  String _nomeTrilha = "Carregando...";
  DateTime? _inicio;
  List<dynamic> _participantes = []; 
  Map<String, dynamic>? _clima; 

  // Timer
  String _tempoDecorrido = "00:00:00";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _iniciarTimer() {
    if (_inicio == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diferenca = DateTime.now().difference(_inicio!);
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      final horas = twoDigits(diferenca.inHours);
      final minutos = twoDigits(diferenca.inMinutes.remainder(60));
      final segundos = twoDigits(diferenca.inSeconds.remainder(60));
      if (mounted) {
        setState(() {
          _tempoDecorrido = "$horas:$minutos:$segundos";
        });
      }
    });
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      // 1. Busca dados da sessão (Nome, Foto)
      final sessionData = await authService.getUserData();

      // 2. Busca dados da Trilha (Nome, Início) e Participantes
      final trilhaData = await apiService.getDetalhesTrilha(widget.trilhaId);

      // 3. Busca dados do Clima (se tivermos localização)
      Map<String, dynamic>? climaData;
      if (widget.userLocation != null) {
        climaData = await apiService.getClima(
          widget.userLocation!.latitude,
          widget.userLocation!.longitude,
        );
      }

      if (mounted) {
        setState(() {
          // (Perfil)
          _userName = sessionData['user_nome'] ?? "Usuário";
          _userPhotoUrl = sessionData['user_foto_url'];

          // (Trilha/Participantes)
          final info = trilhaData['trilha_info'];
          _nomeTrilha = info['nome_trilha'];
          _inicio = DateTime.parse(info['iniciada_em_iso']);
          _participantes = trilhaData['participantes'];
          _clima = climaData;

          _iniciarTimer(); // Inicia o timer com a data correta
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar drawer: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarTrilha() async {
    final bool? confirmar = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Finalizar Trilha?"),
        content: const Text("Isso encerrará o rastreamento e salvará o histórico."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Finalizar")),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await apiService.finalizarTrilha(widget.trilhaId);
        widget.onTrilhaFinalizada(); // Avisa a tela mãe para voltar ao estado Ocioso
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column( // Alterado para Column
        children: [
          // --- PONTO 1: FOTO DE PERFIL ---
          UserAccountsDrawerHeader(
            accountName: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text(_nomeTrilha, style: const TextStyle(fontStyle: FontStyle.italic)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: _userPhotoUrl != null 
                  ? NetworkImage(_userPhotoUrl!) 
                  : null,
              child: _userPhotoUrl == null 
                  ? const Icon(Icons.person, size: 40, color: Colors.grey) 
                  : null,
            ),
            // "Trilha em Andamento" agora é o e-mail
          ),

          // Ocupa o espaço central
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // --- PONTO 2: TIMER ESTILIZADO ---
                Container(
                  color: Colors.black.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _tempoDecorrido,
                        style: const TextStyle(
                          fontSize: 40, 
                          fontWeight: FontWeight.w300, 
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // --- PONTO 5: CLIMA E PARTICIPANTES ---
                if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),

                _buildClimaTile(), // Widget do Clima

                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Participantes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _buildParticipantesList(), // Widget da Lista

              ],
            ),
          ),

          // --- BOTÃO DE FINALIZAR (Sempre no fundo) ---
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _finalizarTrilha,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text("FINALIZAR TRILHA"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets Auxiliares ---

  Widget _buildClimaTile() {
    if (_clima == null) {
      return const ListTile(
        leading: Icon(Icons.cloud_off, color: Colors.grey),
        title: Text("Clima não disponível"),
        subtitle: Text("Não foi possível obter a localização."),
      );
    }
    return ListTile(
      leading: Image.network(
        // URL do ícone do OpenWeatherMap
        'https://openweathermap.org/img/wn/${_clima!['icone']}@2x.png',
      ),
      title: Text("Clima: ${_clima!['descricao']}"),
      subtitle: Text("${_clima!['temp']}°C (Sensação: ${_clima!['sensacao_termica']}°C)"),
    );
  }

  Widget _buildParticipantesList() {
    if (_participantes.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.person, color: Colors.grey),
        title: Text("Apenas você"),
      );
    }

    return ListView.builder(
      itemCount: _participantes.length,
      shrinkWrap: true, // Para caber dentro do outro ListView
      physics: const NeverScrollableScrollPhysics(), // Desabilita scroll
      itemBuilder: (context, index) {
        final user = _participantes[index];
        final fotoUrl = user['url_foto_perfil'] != null 
            ? '${apiService.baseUrl}/uploads/${user['url_foto_perfil']}'
            : null;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
            child: fotoUrl == null ? const Icon(Icons.person) : null,
          ),
          title: Text(user['nome']),
        );
      },
    );
  }
}
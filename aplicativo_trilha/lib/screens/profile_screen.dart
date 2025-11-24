// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Instância do nosso serviço de BD
  final DatabaseService _dbService = DatabaseService.instance;

  // Variáveis para guardar os dados que vêm do banco
  int _totalTagsLidas = 0;
  int _eventosPendentes = 0;
  Map<String, dynamic>? _ultimaTag;

  // Flag de carregamento
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // Função que busca os dados do sqflite
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    // Busca os dados em paralelo
    final total = await _dbService.countTotalEvents();
    final pendentes = await _dbService.countPendingEvents();
    final ultimo = await _dbService.getLastEvent(); 

    // Atualiza o estado da tela com os novos dados
    setState(() {
      _totalTagsLidas = total;
      _eventosPendentes = pendentes;
      _ultimaTag = ultimo;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await authService.logout();

    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Trilheiro (Local)'),
        actions: [
          // Botão de recarregar
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfileData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout, 
          ),
          // ------------------------------------
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Card de Resumo ---
                  _buildMetricCard(
                    title: 'Total de Tags Lidas',
                    value: _totalTagsLidas.toString(),
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),

                  const SizedBox(height: 16),

                  // --- Card de Sincronização ---
                  _buildMetricCard(
                    title: 'Eventos na Fila (Offline)',
                    value: _eventosPendentes.toString(),
                    icon: Icons.sync_problem_outlined,
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 16),

                  // --- Card da Última Tag ---
                  _buildLastTagCard(),
                ],
              ),
            ),
    );
  }

  // Widget auxiliar para criar os cards de métrica
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para o card da última tag
  Widget _buildLastTagCard() {
    if (_ultimaTag == null) {
      return _buildMetricCard(
        title: 'Última Tag Visitada',
        value: 'Nenhuma',
        icon: Icons.location_off_outlined,
        color: Colors.grey,
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flag_outlined, color: Colors.blue, size: 40),
                SizedBox(width: 16),
                Text(
                  'Última Atividade Registrada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            Text('Tag ID: ${_ultimaTag!['id_tag']}'),
            Text('Direção: ${_ultimaTag!['direcao']}'),
            Text('Horário: ${DateTime.parse(_ultimaTag!['timestamp_leitura']).toLocal()}'),
            Text('GPS: ${_ultimaTag!['latitude'].toStringAsFixed(4)}, ${_ultimaTag!['longitude'].toStringAsFixed(4)}'),
          ],
        ),
      ),
    );
  }
}
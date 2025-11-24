// lib/screens/operator_screen.dart
import 'package:flutter/material.dart';
import 'package:aplicativo_trilha/main.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
 

  // Variáveis de estado
  bool _isLoading = true;
  String _erro = "";
  Map<String, dynamic> _dashboardData = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Função que chama a API
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _erro = "";

    });

    try {
      // 1. Chama a API
      final data = await apiService.getDashboardGeral();
      // 2. Atualiza o estado da tela
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _erro = "Erro ao buscar dashboard: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard do Operador (API)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _erro.isNotEmpty
              ? Center(child: Text(_erro, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMetricCard(
                        title: 'Total de Usuários Registrados',
                        value: _dashboardData['total_usuarios']?.toString() ?? '0',
                        icon: Icons.people,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      _buildMetricCard(
                        title: 'Total de Eventos de Passagem',
                        value: _dashboardData['total_eventos_passagem']?.toString() ?? '0',
                        icon: Icons.flag,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      _buildMetricCard(
                        title: 'Total de Agendamentos',
                        value: _dashboardData['total_agendamentos']?.toString() ?? '0',
                        icon: Icons.calendar_today,
                        color: Colors.purple,
                      ),
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
}
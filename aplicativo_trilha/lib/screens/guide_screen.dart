// lib/screens/guide_screen.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:flutter/material.dart';
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
   // Instância do nosso serviço de API
  final TextEditingController _tagIdController = TextEditingController(text: "1");

  // Variáveis de estado da tela
  bool _isLoading = false;
  String _tagSolicitada = "";
  List<dynamic> _passaramPorAqui = []; 
  String _erro = "";

  // Função que chama a API
  Future<void> _fetchTagData() async {
    final int? tagId = int.tryParse(_tagIdController.text);
    if (tagId == null) return;

    setState(() {
      _isLoading = true;
      _erro = "";
      _passaramPorAqui = []; 
    });

    try {
      // 1. Chama a API
      final data = await apiService.getEventosPorTag(tagId);

      // 2. Atualiza o estado da tela com os dados
      setState(() {
        _tagSolicitada = data['tag_solicitada'].toString();
        _passaramPorAqui = data['passaram_por_aqui'] ?? [];
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _erro = "Erro ao buscar dados: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tela do Guia - Verificação'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Seção de Input ---
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID da Tag para Verificar',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.search, size: 40),
                  onPressed: _fetchTagData,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),

            // --- Seção de Resultados ---
            _buildResults(),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para mostrar os resultados
  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro.isNotEmpty) {
      return Center(child: Text(_erro, style: const TextStyle(color: Colors.red)));
    }

    if (_passaramPorAqui.isEmpty && _tagSolicitada.isEmpty) {
      return const Center(child: Text('Digite o ID de uma tag e aperte "Buscar".'));
    }

    if (_passaramPorAqui.isEmpty && _tagSolicitada.isNotEmpty) {
      return Center(child: Text('Ninguém passou pela Tag $_tagSolicitada ainda.'));
    }

    // Se temos dados, mostramos a lista
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Relatório da Tag: $_tagSolicitada',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text('${_passaramPorAqui.length} registros encontrados:'),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _passaramPorAqui.length,
              itemBuilder: (context, index) {
                final evento = _passaramPorAqui[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(evento['nome_usuario'] ?? 'Usuário Desconhecido'),
                    subtitle: Text('Horário: ${evento['timestamp_leitura']}\nDireção: ${evento['direcao']}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
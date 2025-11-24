// lib/screens/start_trail_form_screen.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class StartTrailFormScreen extends StatefulWidget {
  const StartTrailFormScreen({super.key});

  @override
  State<StartTrailFormScreen> createState() => _StartTrailFormScreenState();
}

class _StartTrailFormScreenState extends State<StartTrailFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _nomeTrilhaController = TextEditingController();
  final TextEditingController _duracaoController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  // Valores dos Dropdowns
  String _dificuldadeSelecionada = 'Fácil';
  String _tipoSelecionado = 'Individual';

  bool _isLoading = false;

  // Função Principal de Submit
  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; 
    }

    setState(() => _isLoading = true);

    try {
      // 1. Buscar o ID do usuário logado 
      final userId = await authService.getLoggedInUserId();
      if (userId == null) {
        throw Exception('Usuário não está logado.');
      }

      // 2. Montar o payload (pacote de dados) para a API
      final Map<String, dynamic> dadosTrilha = {
        'id_usuario_lider': int.parse(userId),
        'nome_trilha': _nomeTrilhaController.text,
        'dificuldade': _dificuldadeSelecionada,
        'tipo': _tipoSelecionado,
        'duracao_estimada_min': int.tryParse(_duracaoController.text),
        'notas': _notasController.text,
      };

      // 3. Chamar o ApiService 
      final response = await apiService.iniciarTrilha(dadosTrilha);

      // 4. Sucesso!
      final novaTrilhaId = response['id_trilha_ativa'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trilha ID $novaTrilhaId iniciada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        // 5. Volta para a tela anterior (LiveTrailScreen) e devolve o ID da nova trilha
        Navigator.pop(context, novaTrilhaId);
      }
    } catch (e) {
      // Trata o erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar trilha: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Nova Trilha'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Preencha os dados da sua atividade',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // --- Nome da Trilha ---
              TextFormField(
                controller: _nomeTrilhaController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Trilha (ex: Minha Caminhada)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              // --- Dificuldade e Tipo ---
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Dificuldade', border: OutlineInputBorder()),
                      initialValue: _dificuldadeSelecionada,
                      items: ['Fácil', 'Média', 'Difícil']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _dificuldadeSelecionada = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                      initialValue: _tipoSelecionado,
                      items: ['Individual', 'Grupo']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _tipoSelecionado = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Duração Estimada ---
              TextFormField(
                controller: _duracaoController,
                decoration: const InputDecoration(
                  labelText: 'Duração Estimada (em minutos)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),

              // --- Notas Adicionais ---
              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas (ex: Levarei lanterna)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              // --- Botão de Submit ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('INICIAR TRILHA'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
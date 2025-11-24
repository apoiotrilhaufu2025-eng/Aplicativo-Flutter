// lib/screens/register_screen.dart
import 'dart:io';
import 'package:aplicativo_trilha/main.dart'; 
import 'package:aplicativo_trilha/screens/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controladores do formulário
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _idadeController = TextEditingController();
  final TextEditingController _adminCodeController = TextEditingController();

  // Variáveis de estado
  int _tipoPerfil = 1; // 1: Trilheiro, 2: Guia, 3: Operador
  String? _sexo;
  XFile? _imageFile; 
  bool _isLoading = false;

// --- Funções de Imagem ---
Future<void> _pickImage(ImageSource source) async {
  // 2. VERIFICA A PERMISSÃO ANTES DE USAR
  PermissionStatus status;
  if (source == ImageSource.camera) {
    status = await Permission.camera.request();
  } else {
    status = await Permission.photos.request();
  }

  if (status.isGranted) {
    // 3. PERMISSÃO CONCEDIDA
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      setState(() => _imageFile = pickedFile);
    } catch (e) {
      print("Erro ao pegar imagem: $e");
    }
  } else if (status.isPermanentlyDenied) {
    // 4. PERMISSÃO NEGADA PERMANENTEMENTE
    print("Permissão de ${source.name} negada permanentemente.");
    openAppSettings();
  } else {
    print("Permissão de ${source.name} negada.");
  }
}

 void _showImagePicker() {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galeria'),
            onTap: () {
              _pickImage(ImageSource.gallery); 
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Câmera'),
            onTap: () {
              _pickImage(ImageSource.camera); 
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  );
}

  // --- Função Principal de Registro ---
  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    // 1. Chama o AuthService
    final response = await authService.register(
      nome: _nomeController.text,
      email: _emailController.text,
      senha: _senhaController.text,
      tipoPerfil: _tipoPerfil,
      telefone: _telefoneController.text,
      idade: int.tryParse(_idadeController.text),
      sexo: _sexo,
      adminCode: _adminCodeController.text,
      fotoPerfil: _imageFile,
    );

    setState(() => _isLoading = false);

    // 2. Trata a resposta
    if (response == "OK") {
      // 3. Se deu "OK", busca os dados salvos
      final userData = await authService.getUserData();
      final tipoPerfil = int.parse(userData['user_tipo_perfil'] ?? '1');

      UserProfile profile = UserProfile.trilheiro;
      if(tipoPerfil == 2) profile = UserProfile.guia;
      if(tipoPerfil == 3) profile = UserProfile.operador;

      // 4. Navega para a tela principal (MainShell)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainShell(profile: profile)),
          (route) => false, 
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Nova Conta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Seletor de Foto ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          _imageFile != null ? FileImage(File(_imageFile!.path)) : null,
                      child: _imageFile == null
                          ? const Icon(Icons.person, size: 50, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          onPressed: _showImagePicker,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Campos do Formulário ---
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome Completo*', border: OutlineInputBorder()),
                validator: (v) => (v?.isEmpty ?? true) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail*', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v?.isEmpty ?? true) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                decoration: const InputDecoration(labelText: 'Senha*', border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => (v?.isEmpty ?? true) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _idadeController,
                      decoration: const InputDecoration(labelText: 'Idade', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Sexo', border: OutlineInputBorder()),
                      initialValue: _sexo,
                      items: ['Masculino', 'Feminino', 'Outro']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _sexo = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Seletor de Tipo de Perfil ---
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Tipo de Conta*', border: OutlineInputBorder()),
                initialValue: _tipoPerfil,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Trilheiro')),
                  DropdownMenuItem(value: 2, child: Text('Guia')),
                  DropdownMenuItem(value: 3, child: Text('Operador de Base')),
                ],
                onChanged: (v) => setState(() => _tipoPerfil = v ?? 1),
              ),

              // --- Campo Condicional de Admin ---
              if (_tipoPerfil > 1) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _adminCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Administrador*',
                    border: OutlineInputBorder(),
                    hintText: 'MAPL_ADMIN_2025',
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Código obrigatório para funcionários' : null,
                ),
              ],

              const SizedBox(height: 30),

              // --- Botão de Registrar ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: const Text('CRIAR CONTA'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
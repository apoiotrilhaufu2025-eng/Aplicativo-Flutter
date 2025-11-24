// lib/screens/login_screen.dart
import 'package:aplicativo_trilha/main.dart'; 
import 'package:aplicativo_trilha/screens/main_shell.dart';
import 'package:aplicativo_trilha/screens/register_screen.dart'; 
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  // Função principal de Login
  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    // 1. Chama o AuthService
    final response = await authService.login(
      _emailController.text,
      _senhaController.text,
    );

    setState(() => _isLoading = false);

    // 2. Trata a resposta
    if (response == "OK") {
      // 3. Se deu "OK", busca os dados salvos no SecureStorage
      final userData = await authService.getUserData();
      final tipoPerfil = int.parse(userData['user_tipo_perfil'] ?? '1');

      // Converte o tipo (1=Trilheiro, 2=Guia, 3=Operador) para o enum
      UserProfile profile = UserProfile.trilheiro;
      if(tipoPerfil == 2) profile = UserProfile.guia;
      if(tipoPerfil == 3) profile = UserProfile.operador;

      // 4. Navega para a tela principal (MainShell)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainShell(profile: profile),
          ),
        );
      }
    } else {
      // Mostra o erro da API (ex: "Credenciais inválidas")
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
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Text(
                'Bem-vindo de volta!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v?.isEmpty ?? true) ? 'Digite seu e-mail' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => (v?.isEmpty ?? true) ? 'Digite sua senha' : null,
              ),
              const SizedBox(height: 30),

              // Botão de Login
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: const Text('ENTRAR'),
                    ),

              const SizedBox(height: 20),

              // Botão de Cadastro
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text('Não tem uma conta? Cadastre-se'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
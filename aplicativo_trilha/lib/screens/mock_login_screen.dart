// lib/screens/mock_login_screen.dart
import 'package:aplicativo_trilha/screens/main_shell.dart';
import 'package:flutter/material.dart';

class MockLoginScreen extends StatelessWidget {
  const MockLoginScreen({super.key});

  void _loginAs(BuildContext context, UserProfile profile) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainShell(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulação de Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => _loginAs(context, UserProfile.trilheiro),
              child: const Text('Entrar como TRILHEIRO'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => _loginAs(context, UserProfile.guia),
              child: const Text('Entrar como GUIA'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => _loginAs(context, UserProfile.operador),
              child: const Text('Entrar como OPERADOR DE BASE'),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MockLoginScreen()),
                );
              },
              child: const Text('Acessar Painel de Testes Antigo'),
            ),
          ],
        ),
      ),
    );
  }
}
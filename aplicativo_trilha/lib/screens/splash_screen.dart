// lib/screens/splash_screen.dart
import 'package:aplicativo_trilha/main.dart'; 
import 'package:aplicativo_trilha/screens/login_screen.dart';
import 'package:aplicativo_trilha/screens/main_shell.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Inicia a verificação assim que a tela é construída
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    // Dá um pequeno atraso para a animação de "loading" aparecer
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      // 1. Pergunta ao AuthService se temos dados salvos
      final userData = await authService.getUserData();

      // 2. Verifica se o 'user_id' existe no Secure Storage
      if (userData['user_id'] != null) {

        // --- USUÁRIO ESTÁ LOGADO ---
        print("[SplashScreen] Sessão encontrada. Logando usuário ID: ${userData['user_id']}");

        // Determina o perfil
        final tipoPerfil = int.parse(userData['user_tipo_perfil'] ?? '1');
        UserProfile profile = UserProfile.trilheiro;
        if (tipoPerfil == 2) profile = UserProfile.guia;
        if (tipoPerfil == 3) profile = UserProfile.operador;

        // 3. Navega para a Tela Principal (MainShell)
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainShell(profile: profile),
            ),
          );
        }
      } else {
        // --- NENHUM USUÁRIO LOGADO ---
        print("[SplashScreen] Nenhuma sessão encontrada. Indo para Login.");
        // 4. Navega para a Tela de Login
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        }
      }
    } catch (e) {
      // Em caso de erro, apenas vai para o Login
      print("[SplashScreen] Erro ao checar sessão: $e");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Esta é a tela que o usuário vê enquanto checamos a sessão
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Carregando informações...'),
          ],
        ),
      ),
    );
  }
}
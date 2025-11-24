// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:aplicativo_trilha/screens/profile_screen.dart';
import 'package:aplicativo_trilha/screens/guide_screen.dart';
import 'package:aplicativo_trilha/screens/operator_screen.dart';
import 'package:aplicativo_trilha/screens/live_trail_screen.dart';

// Enum para sabermos qual perfil está logado
enum UserProfile { trilheiro, guia, operador }

class MainShell extends StatefulWidget {
  final UserProfile profile;

  const MainShell({super.key, required this.profile});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // Listas de telas e abas para cada perfil
  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();

    // Configura as telas e abas com base no perfil que logou
    switch (widget.profile) {
      case UserProfile.trilheiro:
        _screens = [
          const LiveTrailScreen(),
          const ProfileScreen(),
        ];
        _navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ];
        break;

      case UserProfile.guia:
        _screens = [
          const GuideScreen(),
          
        ];
        _navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Verificar Tag'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
        ];
        break;

      case UserProfile.operador:
        _screens = [
          const OperatorScreen(),
        ];
        _navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        ];
        break;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O corpo da tela muda conforme a aba selecionada
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // A barra de navegação
      bottomNavigationBar: _navItems.length == 1 
        ? null // Não mostra a barra se for operador (só 1 tela)
        : BottomNavigationBar(
            items: _navItems,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
    );
  }
}
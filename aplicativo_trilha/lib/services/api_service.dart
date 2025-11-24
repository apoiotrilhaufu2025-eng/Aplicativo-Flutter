// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  // O IP do seu PC (onde o api_server.py está) + a porta 5000
  final String baseUrl = 'http://192.168.15.79:5000';

  // Função para o Dashboard do Operador
  Future<Map<String, dynamic>> getDashboardGeral() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/dashboard/geral'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("[ApiService] Erro ${response.statusCode}: ${response.body}");
        throw Exception('Falha ao carregar dashboard');
      }
    } catch (e) {
      print("[ApiService] Exceção: $e");
      throw Exception('Falha ao conectar ao servidor da API');
    }
  }

  // Função para a Tela do Guia 
  Future<Map<String, dynamic>> getEventosPorTag(int tagId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/eventos/tag/$tagId'));

      if (response.statusCode == 200) {
        // O corpo da resposta é o JSON que vimos no navegador
        return jsonDecode(response.body); 
      } else {
        print("[ApiService] Erro ${response.statusCode}: ${response.body}");
        throw Exception('Falha ao carregar eventos da tag');
      }
    } catch (e) {
      print("[ApiService] Exceção: $e");
      throw Exception('Falha ao conectar ao servidor da API');
    }
  }

  Future<Map<String, dynamic>> iniciarTrilha(Map<String, dynamic> dadosTrilha) async {
    print("[ApiService] Enviando dados para /api/trilha/iniciar");
    try {
      final url = Uri.parse('$baseUrl/api/trilha/iniciar');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(dadosTrilha),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) { // 201 = Criado
        return data;
      } else {
        print("[ApiService] Erro ${response.statusCode}: ${data['erro']}");
        throw Exception('Falha ao iniciar trilha: ${data['erro']}');
      }
    } catch (e) {
      print("[ApiService] Exceção: $e");
      throw Exception('Falha ao conectar ao servidor da API');
    }
  }

  /// Busca os detalhes da trilha ativa (para o Drawer)
  Future<Map<String, dynamic>> getDetalhesTrilha(int trilhaId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/trilha/detalhes/$trilhaId'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Falha ao carregar detalhes: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Busca o clima para uma localização (para o Drawer)
  Future<Map<String, dynamic>> getClima(double lat, double lon) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/clima?lat=$lat&lon=$lon'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Falha ao carregar clima: ${response.body}');
      }
    } catch (e) {
      print("[ApiService] Erro getClima: $e");
      rethrow;
    }
  }

  /// Finaliza a trilha ativa
  Future<void> finalizarTrilha(int trilhaId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/trilha/finalizar/$trilhaId'),
      );

      if (response.statusCode != 200) {
        throw Exception('Falha ao finalizar trilha: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

}
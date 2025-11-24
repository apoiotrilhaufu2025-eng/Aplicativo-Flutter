// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // O IP do seu PC onde o api_server.py está rodando
  final String _baseUrl = 'http://192.168.15.79:5000';

  // Instância do nosso armazenamento seguro
  final _storage = const FlutterSecureStorage();

  // --- MÉTODOS DE SESSÃO ---

  // Salva os dados do usuário no armazenamento seguro após o login/registro
  Future<void> _saveUserSession(Map<String, dynamic> userData) async {
    // Converte todos os valores para String, pois o secure_storage só aceita strings
    await _storage.write(key: 'user_id', value: userData['id_usuario']?.toString());
    await _storage.write(key: 'user_nome', value: userData['nome']);
    await _storage.write(key: 'user_email', value: userData['email']);
    await _storage.write(key: 'user_tipo_perfil', value: userData['tipo_perfil']?.toString());

    // A URL da foto pode ser nula, então checamos
    if (userData['url_foto_perfil'] != null) {
      // Criamos a URL completa para o app poder carregar a imagem
      await _storage.write(key: 'user_foto_url', value: '$_baseUrl/uploads/${userData['url_foto_perfil']}');
    } else {
      await _storage.delete(key: 'user_foto_url');
    }
  }

  // Busca os dados do usuário logado 
  Future<Map<String, String?>> getUserData() async {
    return await _storage.readAll();
  }

  // Limpa a sessão (Logout)
  Future<void> logout() async {
    print("[AuthService] Deslogando usuário e limpando sessão.");
    await _storage.deleteAll();
  }

  // --- MÉTODOS DE SESSÃO (Getters) ---

// Retorna o ID do usuário logado (como String), ou null
Future<String?> getLoggedInUserId() async {
  return await _storage.read(key: 'user_id');
}

  // --- MÉTODOS DE API ---

  /// Tenta fazer login. Retorna "OK" em sucesso, ou a mensagem de erro.
  Future<String> login(String email, String senha) async {
    print("[AuthService] Tentando login para: $email");
    try {
      final url = Uri.parse('$_baseUrl/api/login');

      // Requisição POST simples com JSON
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Sucesso! Salva a sessão
        await _saveUserSession(data);
        print("[AuthService] Login bem-sucedido para: ${data['nome']}");
        return "OK";
      } else {
        // Erro (ex: senha errada, usuário não existe)
        print("[AuthService] Falha no login: ${data['erro']}");
        return data['erro'] ?? 'Erro desconhecido';
      }
    } catch (e) {
      print("[AuthService] Exceção no login: $e");
      return "Não foi possível conectar ao servidor.";
    }
  }

  /// Tenta registrar um novo usuário. Retorna "OK" em sucesso, ou a mensagem de erro.
  Future<String> register({
    // Campos de texto
    required String nome,
    required String email,
    required String senha,
    required int tipoPerfil,
    String? telefone,
    int? idade,
    String? sexo,
    String? adminCode,
    // Arquivo de imagem
    XFile? fotoPerfil,
  }) async {
    print("[AuthService] Tentando registrar novo usuário: $email");
    try {
      final url = Uri.parse('$_baseUrl/api/register');

      // 1. Criar uma requisição "Multipart" (para formulários com arquivos)
      var request = http.MultipartRequest('POST', url);

      // 2. Adicionar todos os campos de TEXTO
      request.fields['nome'] = nome;
      request.fields['email'] = email;
      request.fields['senha'] = senha;
      request.fields['tipo_perfil'] = tipoPerfil.toString();

      // Campos opcionais
      if (telefone != null && telefone.isNotEmpty) request.fields['telefone'] = telefone;
      if (idade != null) request.fields['idade'] = idade.toString();
      if (sexo != null) request.fields['sexo'] = sexo;
      if (adminCode != null && adminCode.isNotEmpty) request.fields['admin_code'] = adminCode;

      // 3. Adicionar o arquivo de FOTO (se existir)
      if (fotoPerfil != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto_perfil', // Esta chave DEVE ser a mesma que o 'api_server.py' espera
            fotoPerfil.path,
            filename: fotoPerfil.name, // Nome do arquivo
          ),
        );
        print("[AuthService] Adicionando foto ao upload: ${fotoPerfil.name}");
      }

      // 4. Enviar a requisição
      final streamedResponse = await request.send();

      // 5. Ler a resposta
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) { // 201 = Criado
        // Sucesso! Salva a sessão (login automático após registro)
        await _saveUserSession(data);
        print("[AuthService] Registro bem-sucedido para: ${data['nome']}");
        return "OK";
      } else {
        // Erro (ex: e-mail já existe, código de admin errado)
        print("[AuthService] Falha no registro: ${data['erro']}");
        return data['erro'] ?? 'Erro desconhecido';
      }

    } catch (e) {
      print("[AuthService] Exceção no registro: $e");
      return "Não foi possível conectar ao servidor.";
    }
  }
}
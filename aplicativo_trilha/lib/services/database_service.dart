// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  // --- Configuração do Singleton ---
  // Isso garante que teremos apenas uma instância desta classe.
  static final DatabaseService instance = DatabaseService._privateConstructor();
  static Database? _database;

  DatabaseService._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Se _database é nulo, inicializamos ele
    _database = await _initDB();
    return _database!;
  }

  // --- Inicialização do Banco de Dados ---
  Future<Database> _initDB() async {
    // Encontra o caminho padrão para bancos de dados no dispositivo
    String path = join(await getDatabasesPath(), 'trilha_local_buffer.db');

    return await openDatabase(
      path,
      version: 1, // Usado para migrações de banco
      onCreate: _createDB, // Função que será chamada na primeira vez que o BD for criado
    );
  }

  // --- Criação da Tabela ---
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS eventos_buffer (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_usuario TEXT NOT NULL, -- CPF do trilheiro, como você mencionou
      id_tag INT NOT NULL,
      timestamp_leitura TEXT NOT NULL, -- Vamos salvar como string no formato ISO 8601
      direcao TEXT NOT NULL, -- 'ida' ou 'volta'
      heading_graus REAL NOT NULL,
      latitude REAL NOT NULL,   
    longitude REAL NOT NULL,
      status_sincronizacao TEXT NOT NULL DEFAULT 'pendente' -- 'pendente', 'concluido'
    )
    ''');
    print("[DatabaseService] Tabela 'eventos_buffer' criada com sucesso!");
  }

  // --- Métodos de CRUD (Create, Read, Update, Delete) ---

  // CREATE: Insere um novo evento no buffer 
  // O 'event' será um Map, ex: {'id_usuario': '123...', 'id_tag': 1, ...}
  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await instance.database;
    print("[DatabaseService] Inserindo evento no buffer: $event");
    return await db.insert('eventos_buffer', event);
  }

  // READ: Busca todos os eventos pendentes 
  Future<List<Map<String, dynamic>>> getPendingEvents() async {
  final db = await instance.database;
  return await db.query(
    'eventos_buffer',
    where: 'status_sincronizacao = ?',
    whereArgs: ['pendente'],
    orderBy: 'id ASC',
  );
  }

  // UPDATE: Atualiza o status de um evento 
  Future<int> updateEventStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'eventos_buffer',
      {'status_sincronizacao': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // READ: Busca o último evento inserido 
  Future<Map<String, dynamic>?> getLastEvent() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'eventos_buffer',
      orderBy: 'id DESC', // Ordena do mais novo para o mais antigo
      limit: 1,           // Pega apenas o primeiro (o mais novo)
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

    // MÉTRICA 1: Contar o total de eventos registrados
  Future<int> countTotalEvents() async {
    final db = await instance.database;
    // O Sqflite nos dá um helper para contar
    final int? count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM eventos_buffer'));
    return count ?? 0;
  }

  // MÉTRICA 2: Contar apenas os eventos pendentes de sincronização
  Future<int> countPendingEvents() async {
    final db = await instance.database;
    final int? count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM eventos_buffer WHERE status_sincronizacao = ?',
        ['pendente']));
    return count ?? 0;
  }
}
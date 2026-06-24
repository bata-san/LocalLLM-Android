import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/chat_message.dart';

class ChatDb {
  Database? _db;

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'chat.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) => db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      '''),
    );
  }

  Future<int> insert(ChatMessage msg) async {
    return await _db!.insert('messages', msg.toMap());
  }

  Future<List<ChatMessage>> loadAll({int limit = 200}) async {
    final rows = await _db!.query(
      'messages',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> clear() async {
    await _db!.delete('messages');
  }

  Future<void> deleteById(int id) async {
    await _db!.delete('messages', where: 'id = ?', whereArgs: [id]);
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbManager {
  static Database? _db;
  static Future<void>? _initFuture;

  static Future<void> init() async {
    if (_db != null) return;
    
    // Prevent race conditions
    _initFuture ??= _initImpl();
    await _initFuture;
  }

  static Future<void> _initImpl() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'donggong.db');

    _db = await openDatabase(
      path,
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS gallery_cache (id INTEGER PRIMARY KEY, json TEXT, timestamp INTEGER)',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS recent_searches (query TEXT PRIMARY KEY, timestamp INTEGER)',
          );
        }
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE IF NOT EXISTS favorites (type TEXT, value TEXT, PRIMARY KEY(type, value))',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS recent_viewed (id INTEGER PRIMARY KEY, timestamp INTEGER)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS gallery_cache (id INTEGER PRIMARY KEY, json TEXT, timestamp INTEGER)',
        );
        await db.execute(
          'CREATE TABLE IF NOT EXISTS recent_searches (query TEXT PRIMARY KEY, timestamp INTEGER)',
        );
      },
    );
  }

  static Database get db {
    if (_db == null) throw StateError('DB not initialized');
    return _db!;
  }

  // ─── Settings ───
  static Future<Map<String, String>> loadSettings() async {
    final rows = await db.query('settings');
    final Map<String, String> result = {};
    for (var row in rows) {
      result[row['key'] as String] = row['value'] as String;
    }
    return result;
  }

  static Future<void> saveSetting(String key, String value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Favorites ───
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    // Order by ROWID ensures insertion order is preserved
    return await db.query('favorites', orderBy: 'ROWID ASC');
  }

  static Future<void> addFavorite(String type, String value) async {
    await db.insert(
      'favorites',
      {'type': type, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> removeFavorite(String type, String value) async {
    await db.delete(
      'favorites',
      where: 'type = ? AND value = ?',
      whereArgs: [type, value],
    );
  }

  // ─── History (Recent Viewed) ───
  static Future<List<int>> getRecentViewedIds({int limit = 50}) async {
    final rows = await db.query(
      'recent_viewed',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((e) => e['id'] as int).toList();
  }

  static Future<void> addRecentViewed(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'recent_viewed',
      {'id': id, 'timestamp': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Trim
    await db.rawDelete(
      'DELETE FROM recent_viewed WHERE id NOT IN (SELECT id FROM recent_viewed ORDER BY timestamp DESC LIMIT 50)',
    );
  }

  // ─── Recent Searches ───
  static Future<List<String>> getRecentSearches({int limit = 20}) async {
    final rows = await db.query(
      'recent_searches',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((e) => e['query'] as String).toList();
  }

  static Future<void> addRecentSearch(String query) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'recent_searches',
      {'query': query, 'timestamp': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.rawDelete(
      'DELETE FROM recent_searches WHERE query NOT IN (SELECT query FROM recent_searches ORDER BY timestamp DESC LIMIT 20)',
    );
  }

  static Future<void> removeRecentSearch(String query) async {
    await db.delete('recent_searches', where: 'query = ?', whereArgs: [query]);
  }

  // ─── Gallery Cache ───
  static Future<List<Map<String, dynamic>>> getCachedGalleries(List<int> ids) async {
    if (ids.isEmpty) return [];
    
    // Split into chunks of 100 to avoid "too many SQL variables" error and improve performance
    final chunks = <List<int>>[];
    for (var i = 0; i < ids.length; i += 100) {
      chunks.add(ids.sublist(i, (i + 100) < ids.length ? i + 100 : ids.length));
    }

    final List<Map<String, dynamic>> results = [];
    for (final chunk in chunks) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        'gallery_cache',
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );
      results.addAll(rows);
    }
    return results;
  }

  static Future<void> cacheGallery(int id, String jsonString) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'gallery_cache',
      {'id': id, 'json': jsonString, 'timestamp': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> resetAllData() async {
    final batch = db.batch();
    batch.delete('favorites');
    batch.delete('settings');
    batch.delete('recent_viewed');
    batch.delete('gallery_cache');
    batch.delete('recent_searches');
    await batch.commit(noResult: true);
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/asset.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'asset_inventory.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE assets ADD COLUMN updated_at TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE assets ADD COLUMN image_path TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE assets ADD COLUMN note TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE assets ADD COLUMN legacy_inv_code TEXT');
      await db.execute('ALTER TABLE assets ADD COLUMN sticker_status TEXT');
    }
    await _createIndexes(db);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE assets (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        location TEXT,
        specs TEXT,
        image_path TEXT,
        updated_at TEXT,
        note TEXT,
        legacy_inv_code TEXT,
        sticker_status TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assets_id ON assets(id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assets_location ON assets(location)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_assets_legacy ON assets(legacy_inv_code)');
  }

  // CRUD Operations
  Future<void> insertAsset(Asset asset) async {
    final db = await database;
    await db.insert(
      'assets',
      asset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Asset>> getAllAssets({int limit = 150, String? query, String? statusFilter}) async {
    final db = await database;
    String? where;
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      where = '(LOWER(id) LIKE ? OR LOWER(type) LIKE ? OR LOWER(location) LIKE ? OR LOWER(COALESCE(legacy_inv_code, "")) LIKE ?)';
      whereArgs.addAll([q, q, q, q]);
    }

    if (statusFilter != null && statusFilter != 'ALL') {
      if (where != null) {
        where += ' AND status = ?';
      } else {
        where = 'status = ?';
      }
      whereArgs.add(statusFilter);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'assets',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      limit: limit,
      orderBy: 'id ASC',
    );
    return List.generate(maps.length, (i) => Asset.fromMap(maps[i]));
  }

  Future<Asset?> getAsset(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Asset.fromMap(maps.first);
  }

  Future<void> updateAsset(Asset asset) async {
    final db = await database;
    await db.update(
      'assets',
      asset.toMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
  }

  Future<void> deleteAsset(String id) async {
    final db = await database;
    await db.delete(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Asset>> getUnsyncedAssets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'assets',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) => Asset.fromMap(maps[i]));
  }

  Future<void> markAsSynced(String id, [String? serverImagePath]) async {
    final db = await database;
    final Map<String, dynamic> updateValues = {'is_synced': 1};
    if (serverImagePath != null && serverImagePath.isNotEmpty) {
      updateValues['image_path'] = serverImagePath;
    }
    await db.update(
      'assets',
      updateValues,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getAssetCounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM assets 
      GROUP BY status
    ''');

    Map<String, int> counts = {
      'TOTAL': 0,
      'AVAILABLE': 0,
      'IN_USE': 0,
      'BROKEN': 0,
    };

    int total = 0;
    for (var map in maps) {
      String status = map['status'] as String;
      int count = map['count'] as int;
      counts[status] = count;
      total += count;
    }
    counts['TOTAL'] = total;

    // Floor counts
    final List<Map<String, dynamic>> floorMaps = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN location LIKE 'Floor Lt2%' THEN 1 ELSE 0 END) as floor2,
        SUM(CASE WHEN location LIKE 'Floor Lt3%' THEN 1 ELSE 0 END) as floor3
      FROM assets
    ''');

    if (floorMaps.isNotEmpty) {
      counts['FLOOR_2'] = (floorMaps.first['floor2'] ?? 0) as int;
      counts['FLOOR_3'] = (floorMaps.first['floor3'] ?? 0) as int;
    } else {
      counts['FLOOR_2'] = 0;
      counts['FLOOR_3'] = 0;
    }

    return counts;
  }

  // Batch Sync (Pull from Server)
  Future<void> syncAssets(List<Asset> remoteAssets) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Delete all currently SYNCED assets (keep unsynced local changes)
      await txn.delete(
        'assets',
        where: 'is_synced = ?',
        whereArgs: [1],
      );

      // 2. Batch insert all assets from server
      final batch = txn.batch();
      for (var asset in remoteAssets) {
        // Ensure isSynced is true for data coming from server
        var assetMap = asset.toMap();
        assetMap['is_synced'] = 1;
        
        batch.insert(
          'assets',
          assetMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}

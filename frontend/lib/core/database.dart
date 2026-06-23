// lib/core/database.dart
// SQLite database manager using sqflite_common_ffi for Windows desktop.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  /// Call once before runApp() on Windows.
  static void initFfi() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'telecom_analyzer.db');
    debugPrint('[DB] Opening database at $path');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cdr (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caller_number TEXT NOT NULL,
        receiver_number TEXT NOT NULL,
        call_time TEXT NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        call_type TEXT DEFAULT 'unknown',
        imei_number TEXT,
        cell_id TEXT,
        latitude REAL,
        longitude REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE sdr (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_number TEXT NOT NULL,
        subscriber_name TEXT,
        address TEXT,
        activation_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tdr (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cell_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        azimuth REAL
      )
    ''');
  }

  // ── CDR ─────────────────────────────────────────────────────────────────────

  Future<int> insertCdrBatch(List<Map<String, dynamic>> rows) async {
    final database = await db;
    var inserted = 0;
    final batch = database.batch();
    for (final row in rows) {
      batch.insert('cdr', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      inserted++;
    }
    await batch.commit(noResult: true);
    return inserted;
  }

  Future<List<Map<String, dynamic>>> queryCdrByPhone(String phone) async {
    final database = await db;
    return database.query(
      'cdr',
      where: 'caller_number = ? OR receiver_number = ?',
      whereArgs: [phone, phone],
      orderBy: 'call_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> queryCdrByImei(String imei) async {
    final database = await db;
    return database.query(
      'cdr',
      where: 'imei_number = ?',
      whereArgs: [imei],
      orderBy: 'call_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> queryAllCdrWithGps() async {
    final database = await db;
    return database.query(
      'cdr',
      where: 'latitude IS NOT NULL AND longitude IS NOT NULL',
      orderBy: 'call_time ASC',
    );
  }

  Future<List<Map<String, dynamic>>> queryAllCdr() async {
    final database = await db;
    return database.query('cdr', orderBy: 'call_time DESC');
  }

  // ── SDR ─────────────────────────────────────────────────────────────────────

  Future<int> insertSdrBatch(List<Map<String, dynamic>> rows) async {
    final database = await db;
    var inserted = 0;
    final batch = database.batch();
    for (final row in rows) {
      batch.insert('sdr', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      inserted++;
    }
    await batch.commit(noResult: true);
    return inserted;
  }

  Future<Map<String, dynamic>?> querySdrByPhone(String phone) async {
    final database = await db;
    final rows = await database.query(
      'sdr',
      where: 'phone_number = ?',
      whereArgs: [phone],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ── TDR ─────────────────────────────────────────────────────────────────────

  Future<int> insertTdrBatch(List<Map<String, dynamic>> rows) async {
    final database = await db;
    var inserted = 0;
    final batch = database.batch();
    for (final row in rows) {
      batch.insert('tdr', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      inserted++;
    }
    await batch.commit(noResult: true);
    return inserted;
  }

  Future<List<Map<String, dynamic>>> queryAllTdr() async {
    final database = await db;
    return database.query('tdr');
  }

  // ── Stats ────────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getTableCounts() async {
    final database = await db;
    final cdrCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM cdr'),
    ) ?? 0;
    final sdrCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM sdr'),
    ) ?? 0;
    final tdrCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM tdr'),
    ) ?? 0;
    return {'cdr': cdrCount, 'sdr': sdrCount, 'tdr': tdrCount};
  }

  Future<void> clearTable(String table) async {
    final database = await db;
    await database.delete(table);
  }
}

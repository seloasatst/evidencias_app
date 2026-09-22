import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/attendance_record.dart';

class ChecadorDbService {
  static final ChecadorDbService instance = ChecadorDbService._init();
  static Database? _database;

  ChecadorDbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('checador_seloasa.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        is_mocked INTEGER NOT NULL,
        status TEXT NOT NULL,
        retardo_minutes INTEGER NOT NULL DEFAULT 0,
        is_overtime INTEGER NOT NULL DEFAULT 0,
        overtime_reason TEXT,
        is_justified INTEGER NOT NULL DEFAULT 0,
        justification_reason TEXT,
        justified_at TEXT
      )
    ''');
  }

  Future<int> insertRecord(AttendanceRecord record) async {
    final db = await instance.database;
    return await db.insert('attendance_records', record.toMap());
  }

  Future<List<AttendanceRecord>> getAllRecords() async {
    final db = await instance.database;
    final result = await db.query(
      'attendance_records',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<List<AttendanceRecord>> getTodayRecords() async {
    final db = await instance.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final result = await db.query(
      'attendance_records',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp ASC',
    );
    return result.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<List<AttendanceRecord>> getRecordsForQuincena(DateTime date) async {
    final db = await instance.database;
    final isFirstQuincena = date.day <= 15;

    final startDay = isFirstQuincena ? 1 : 16;
    final endDay = isFirstQuincena
        ? 15
        : DateTime(date.year, date.month + 1, 0).day;

    final start = DateTime(date.year, date.month, startDay, 0, 0, 0).toIso8601String();
    final end = DateTime(date.year, date.month, endDay, 23, 59, 59).toIso8601String();

    final result = await db.query(
      'attendance_records',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start, end],
      orderBy: 'timestamp DESC',
    );

    return result.map((map) => AttendanceRecord.fromMap(map)).toList();
  }

  Future<int> updateJustification({
    required int id,
    required String reason,
    required DateTime justifiedAt,
  }) async {
    final db = await instance.database;
    return await db.update(
      'attendance_records',
      {
        'is_justified': 1,
        'justification_reason': reason,
        'justified_at': justifiedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> purgeDuplicateRecords() async {
    final db = await instance.database;
    final result = await db.query('attendance_records', orderBy: 'timestamp ASC');
    if (result.isEmpty) return 0;

    final allRecords = result.map((map) => AttendanceRecord.fromMap(map)).toList();
    final List<int> idsToDelete = [];
    final List<String> photosToDelete = [];

    final Map<String, List<AttendanceRecord>> grouped = {};
    for (var r in allRecords) {
      grouped.putIfAbsent(r.type.dbValue, () => []).add(r);
    }

    for (var list in grouped.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (int i = 0; i < list.length; i++) {
        final current = list[i];
        if (idsToDelete.contains(current.id)) continue;

        for (int j = i + 1; j < list.length; j++) {
          final next = list[j];
          if (idsToDelete.contains(next.id)) continue;

          final diff = next.timestamp.difference(current.timestamp).abs();
          final sameDay = current.timestamp.year == next.timestamp.year &&
              current.timestamp.month == next.timestamp.month &&
              current.timestamp.day == next.timestamp.day;

          if (sameDay && diff.inSeconds <= 60) {
            if (next.id != null) {
              idsToDelete.add(next.id!);
              if (next.photoPath.isNotEmpty && next.photoPath != current.photoPath) {
                photosToDelete.add(next.photoPath);
              }
            }
          }
        }
      }
    }

    if (idsToDelete.isNotEmpty) {
      await db.delete(
        'attendance_records',
        where: 'id IN (${idsToDelete.join(',')})',
      );

      for (var path in photosToDelete) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }

    return idsToDelete.length;
  }
}

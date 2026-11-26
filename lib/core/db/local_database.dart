import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._();
  LocalDatabase._();

  Database? _db;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    _db ??= await init();
    return _db;
  }

  Future<Database?> init() async {
    if (kIsWeb) return null;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'tripmate.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      return _db;
    } catch (e) {
      return null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Offline attendance queue
    await db.execute('''
      CREATE TABLE offline_attendance (
        id            TEXT PRIMARY KEY,
        session_id    TEXT NOT NULL,
        student_id    TEXT NOT NULL,
        trip_id       TEXT NOT NULL,
        stage_id      TEXT NOT NULL,
        bus_id        TEXT NOT NULL,
        route_id      TEXT NOT NULL,
        attendance_type TEXT NOT NULL DEFAULT 'boarding',
        method        TEXT NOT NULL DEFAULT 'qr',
        latitude      REAL,
        longitude     REAL,
        accuracy      REAL,
        boarded_location TEXT,
        marked_at     TEXT NOT NULL,
        status        TEXT NOT NULL DEFAULT 'present',
        is_synced     INTEGER NOT NULL DEFAULT 0,
        sync_error    TEXT,
        created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Cached student registry (for offline lookup)
    await db.execute('''
      CREATE TABLE cached_students (
        id            TEXT PRIMARY KEY,
        roll_number   TEXT NOT NULL,
        name          TEXT NOT NULL,
        class_name    TEXT,
        department    TEXT,
        qr_code       TEXT NOT NULL,
        assigned_bus_id TEXT,
        assigned_stage_id TEXT,
        parent_phone  TEXT,
        cached_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Active session metadata cache
    await db.execute('''
      CREATE TABLE active_sessions (
        id            TEXT PRIMARY KEY,
        trip_id       TEXT NOT NULL,
        stage_id      TEXT NOT NULL,
        bus_id        TEXT NOT NULL,
        route_id      TEXT NOT NULL,
        trip_type     TEXT NOT NULL,
        bus_number    TEXT,
        route_name    TEXT,
        stage_name    TEXT,
        stage_lat     REAL,
        stage_lon     REAL,
        stage_radius  REAL,
        started_at    TEXT NOT NULL,
        status        TEXT NOT NULL DEFAULT 'open'
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_offline_synced ON offline_attendance(is_synced)');
    await db.execute('CREATE INDEX idx_offline_session ON offline_attendance(session_id)');
    await db.execute('CREATE INDEX idx_student_qr ON cached_students(qr_code)');
    await db.execute('CREATE INDEX idx_student_roll ON cached_students(roll_number)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      await db.execute('ALTER TABLE offline_attendance ADD COLUMN accuracy REAL');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE offline_attendance ADD COLUMN boarded_location TEXT');
    } catch (_) {}
  }

  // ============================================================
  // Offline Attendance Queue
  // ============================================================

  Future<String> insertOfflineAttendance(Map<String, dynamic> record) async {
    final db = await database;
    if (db == null) return record['id'] as String;
    await db.insert('offline_attendance', record, conflictAlgorithm: ConflictAlgorithm.replace);
    return record['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getPendingAttendance() async {
    final db = await database;
    if (db == null) return [];
    return db.query('offline_attendance', where: 'is_synced = 0', orderBy: 'created_at ASC');
  }

  Future<void> markAttendanceSynced(String id) async {
    final db = await database;
    if (db == null) return;
    await db.update(
      'offline_attendance',
      {'is_synced': 1, 'sync_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAttendanceSyncFailed(String id, String error) async {
    final db = await database;
    if (db == null) return;
    await db.update(
      'offline_attendance',
      {'sync_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPendingCount() async {
    final db = await database;
    if (db == null) return 0;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM offline_attendance WHERE is_synced = 0');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ============================================================
  // Cached Students
  // ============================================================

  Future<void> cacheStudents(List<Map<String, dynamic>> students) async {
    final db = await database;
    if (db == null) return;
    final batch = db.batch();
    for (final s in students) {
      final id = s['id']?.toString() ?? '';
      final roll = s['roll_number']?.toString() ?? '';
      if (id.isEmpty || roll.isEmpty) continue;

      final filtered = <String, dynamic>{
        'id': id,
        'roll_number': roll,
        'name': s['name']?.toString() ?? 'Student',
        'class_name': s['class_name']?.toString(),
        'department': s['department']?.toString(),
        'qr_code': (s['qr_code'] ?? roll).toString(),
        'assigned_bus_id': s['assigned_bus_id']?.toString(),
        'assigned_stage_id': s['assigned_stage_id']?.toString(),
        'parent_phone': s['parent_phone']?.toString(),
      };
      batch.insert('cached_students', filtered, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  String _sanitizeBarcode(String code) {
    var s = code.trim();
    // 1. Strip AIM Symbology identifier (e.g. ]C1, ]c1, ]C0, ]Q1, ]d2, ]A0, ]e0)
    s = s.replaceFirst(RegExp(r'^\][a-zA-Z0-9]{2}'), '');
    // 2. Strip common scanner wedge prefixes like cn1 or ]c1
    s = s.replaceFirst(RegExp(r'^(?:cn1|\]c1)', caseSensitive: false), '');
    // 3. Strip control characters like FNC1 separator (\x1D), nulls, tabs, newlines
    s = s.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    return s.trim();
  }

  Future<Map<String, dynamic>?> findStudentByQR(String qrCode) async {
    final db = await database;
    if (db == null) return null;
    final clean = _sanitizeBarcode(qrCode);
    final cleanUpper = clean.toUpperCase();
    final core = cleanUpper.replaceFirst(RegExp(r'^C1?'), '').replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final withC1 = core.isNotEmpty ? 'C1$core' : cleanUpper;
    final withC = core.isNotEmpty ? 'C$core' : cleanUpper;

    final rows = await db.query(
      'cached_students',
      where: '''
        qr_code = ? OR roll_number = ? OR 
        qr_code = ? OR roll_number = ? OR 
        UPPER(qr_code) = ? OR UPPER(roll_number) = ? OR
        UPPER(roll_number) = ? OR UPPER(qr_code) = ? OR
        UPPER(roll_number) = ? OR UPPER(qr_code) = ? OR
        UPPER(roll_number) = ? OR UPPER(qr_code) = ?
      ''',
      whereArgs: [
        qrCode, qrCode,
        clean, clean,
        cleanUpper, cleanUpper,
        core, core,
        withC1, withC1,
        withC, withC,
      ],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first;

    // Suffix matching if core code is at least 5 chars (e.g. 26SCBA14)
    if (core.length >= 5) {
      final suffixRows = await db.rawQuery(
        'SELECT * FROM cached_students WHERE UPPER(roll_number) LIKE ? OR UPPER(qr_code) LIKE ? LIMIT 1',
        ['%$core', '%$core'],
      );
      if (suffixRows.isNotEmpty) return suffixRows.first;
    }

    return null;
  }

  Future<Map<String, dynamic>?> findStudentByRoll(String rollNumber) async {
    final db = await database;
    if (db == null) return null;
    final clean = _sanitizeBarcode(rollNumber);
    final cleanUpper = clean.toUpperCase();
    final core = cleanUpper.replaceFirst(RegExp(r'^C1?'), '').replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final withC1 = core.isNotEmpty ? 'C1$core' : cleanUpper;
    final withC = core.isNotEmpty ? 'C$core' : cleanUpper;

    final rows = await db.query(
      'cached_students',
      where: '''
        roll_number = ? OR qr_code = ? OR
        roll_number = ? OR qr_code = ? OR
        UPPER(roll_number) = ? OR UPPER(qr_code) = ? OR
        UPPER(roll_number) = ? OR UPPER(qr_code) = ? OR
        UPPER(roll_number) = ? OR UPPER(qr_code) = ? OR
        UPPER(roll_number) = ? OR UPPER(qr_code) = ?
      ''',
      whereArgs: [
        rollNumber, rollNumber,
        clean, clean,
        cleanUpper, cleanUpper,
        core, core,
        withC1, withC1,
        withC, withC,
      ],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first;

    if (core.length >= 5) {
      final suffixRows = await db.rawQuery(
        'SELECT * FROM cached_students WHERE UPPER(roll_number) LIKE ? OR UPPER(qr_code) LIKE ? LIMIT 1',
        ['%$core', '%$core'],
      );
      if (suffixRows.isNotEmpty) return suffixRows.first;
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final db = await database;
    if (db == null) return [];
    final q = '%${query.toLowerCase()}%';
    return db.rawQuery(
      'SELECT * FROM cached_students WHERE LOWER(name) LIKE ? OR LOWER(roll_number) LIKE ? LIMIT 10',
      [q, q],
    );
  }

  // ============================================================
  // Active Session Cache
  // ============================================================

  Future<void> saveActiveSession(Map<String, dynamic> session) async {
    final db = await database;
    if (db == null) return;
    await db.insert('active_sessions', session, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getActiveSession(String sessionId) async {
    final db = await database;
    if (db == null) return null;
    final rows = await db.query('active_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> clearSessions() async {
    final db = await database;
    if (db == null) return;
    await db.delete('active_sessions');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}

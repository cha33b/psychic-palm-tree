import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  /// Optional override for the database directory, intended for tests so an
  /// isolated temp directory is used instead of the application's real storage.
  static String? overrideDbDir;

  /// Public accessor for the underlying database file, used for backup/export.
  Future<File> get databaseFile async {
    final db = await database;
    return File(db.path);
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Closes and forgets the cached database so the next call to [database]
  /// re-opens it. Primarily used by tests to reset state between cases.
  Future<void> close() async {
    if (_database != null) {
      final db = _database!;
      await db.close();
      _database = null;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await _databaseDirectory();
    print('DB PATH: $dbPath/salary_manager.db');

    return databaseFactory.openDatabase(
      join(dbPath, 'salary_manager.db'),
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // Foreign-key support is opt-in in SQLite; enable it so the
        // cascading rules declared in the schema actually take effect.
        onOpen: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  Future<void> diagnoseAttendance(int projectId, String fromDate, String toDate) async {
    final db = await database;

    print('=== DIAGNOSTIC START ===');
    print('DB diagnoseAttendance: projectId=$projectId, fromDate=$fromDate, toDate=$toDate');

    // 1. Workers table
    final workers = await db.rawQuery('''
      SELECT id, reference, full_name, project_id, company_id
      FROM workers
      ORDER BY id
    ''');
    print('WORKERS TABLE (${workers.length} rows):');
    for (final w in workers) {
      print('  id=${w['id']}, ref=${w['reference']}, name=${w['full_name']}, project_id=${w['project_id']}, company_id=${w['company_id']}');
    }

    // 2. Attendance table
    final attendance = await db.rawQuery('''
      SELECT id, worker_id, project_id, attendance_date,
             status, additional_hours, hour_price
      FROM attendance
      ORDER BY id DESC
    ''');
    print('ATTENDANCE TABLE (${attendance.length} rows):');
    for (final a in attendance) {
      print('  id=${a['id']}, worker_id=${a['worker_id']}, project_id=${a['project_id']}, date=${a['attendance_date']}, status=${a['status']}, ot=${a['additional_hours']}, price=${a['hour_price']}');
    }

    // 3. Projects table
    final projects = await db.rawQuery('''
      SELECT id, reference, name, company_id
      FROM projects
      ORDER BY id
    ''');
    print('PROJECTS TABLE (${projects.length} rows):');
    for (final p in projects) {
      print('  id=${p['id']}, ref=${p['reference']}, name=${p['name']}, company_id=${p['company_id']}');
    }

    // 4. Companies table
    final companies = await db.rawQuery('''
      SELECT id, reference, name
      FROM companies
      ORDER BY id
    ''');
    print('COMPANIES TABLE (${companies.length} rows):');
    for (final c in companies) {
      print('  id=${c['id']}, ref=${c['reference']}, name=${c['name']}');
    }

    // 5. The exact query from getAttendanceRange
    final rows = await db.rawQuery(
      '''
    SELECT
      workers.id,
      workers.reference,
      workers.full_name AS name,
      workers.project_id AS worker_project_id,
      attendance.id AS attendance_id,
      attendance.worker_id AS attendance_worker_id,
      attendance.project_id AS attendance_project_id,
      attendance.attendance_date,
      attendance.status,
      attendance.additional_hours,
      attendance.hour_price
    FROM workers
    LEFT JOIN attendance
      ON workers.id = attendance.worker_id
      AND date(attendance.attendance_date) >= date(?)
      AND date(attendance.attendance_date) <= date(?)
    WHERE workers.project_id = ?
    ORDER BY workers.reference, attendance.attendance_date
    ''',
      [fromDate, toDate, projectId],
    );
    print('JOIN QUERY RESULT (${rows.length} rows):');
    for (final row in rows) {
      print('  workerId=${row['id']}, workerProj=${row['worker_project_id']}, attId=${row['attendance_id']}, attWorkerId=${row['attendance_worker_id']}, attProj=${row['attendance_project_id']}, date=${row['attendance_date']}, status=${row['status']}, ot=${row['additional_hours']}, price=${row['hour_price']}');
    }

    print('=== DIAGNOSTIC END ===');
  }

  /// Resolves a platform-appropriate directory for the database file.
  /// On desktop the FFI `getDatabasesPath()` is used; on mobile the
  /// application documents directory is used instead.
  Future<String> _databaseDirectory() async {
    if (overrideDbDir != null) {
      return overrideDbDir!;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    return getDatabasesPath();
  }

  Future<List<Map<String, dynamic>>> getAttendanceRange({
    required int projectId,
    int? companyId,
    String? fromDate,
    String? toDate,
    List<int>? workerIds,
  }) async {
    final db = await database;

    print(
      'DB GET ATTENDANCE RANGE: projectId=$projectId, companyId=$companyId, fromDate=$fromDate, toDate=$toDate, workerIds=$workerIds',
    );

    // Run diagnostic to see actual DB state
    if (fromDate != null && toDate != null) {
      await diagnoseAttendance(projectId, fromDate, toDate);
    }

    // Build params in the EXACT order they appear in the SQL (left-to-right):
    // 1. ON clause dates (fromDate, toDate) - must come FIRST
    // 2. WHERE project_id
    // 3. WHERE company_id (optional)
    // 4. WHERE workerIds IN (...) (optional)
    List<dynamic> params = [];
    String onClause = 'ON workers.id = attendance.worker_id';
    String whereClause = 'workers.project_id = ?';

    if (fromDate != null && toDate != null) {
      onClause += ' AND date(attendance.attendance_date) >= date(?)';
      onClause += ' AND date(attendance.attendance_date) <= date(?)';
      params.addAll([fromDate, toDate]);  // ON clause params FIRST
    }

    params.add(projectId);  // WHERE project_id

    if (companyId != null) {
      whereClause += ' AND workers.company_id = ?';
      params.add(companyId);
    }

    if (workerIds != null && workerIds.isNotEmpty) {
      final placeholders = List.filled(workerIds.length, '?').join(',');
      whereClause += ' AND workers.id IN ($placeholders)';
      params.addAll(workerIds);
    }

    final sql = '''
  SELECT
    workers.id AS id,
    workers.reference,
    workers.full_name AS name,
    attendance.attendance_date,
    attendance.status,
    attendance.additional_hours,
    attendance.hour_price
  FROM workers
  LEFT JOIN attendance
    $onClause
  WHERE $whereClause
  ORDER BY
    workers.reference,
    attendance.attendance_date
  ''';

    print('DB GET ATTENDANCE RANGE SQL: $sql');
    print('DB GET ATTENDANCE RANGE PARAMS: $params');

    final rows = await db.rawQuery(sql, params);

    print('DB GET ATTENDANCE RANGE: raw rows count = ${rows.length}');
    for (final row in rows) {
      print('  Row: workerId=${row['id']}, date=${row['attendance_date']}, status=${row['status']}, ot=${row['additional_hours']}, price=${row['hour_price']}');
    }

    // Pivot: one map per worker with date-string keys -> status values
    final Map<int, Map<String, dynamic>> workerMap = {};
    for (final row in rows) {
      final workerId = row['id'] as int;
      final workerData = workerMap.putIfAbsent(workerId, () => {
        'id': workerId,
        'reference': row['reference'],
        'name': row['name'],
        'full_name': row['name'],
        'additional_hours': <String, double>{},
        'hour_price': <String, double>{},
      });

      final dateStr = row['attendance_date'] as String?;
      if (dateStr != null && row['status'] != null) {
        workerData[dateStr] = row['status'] as String;
        final additionalHours = (row['additional_hours'] as num?)?.toDouble() ?? 0;
        if (additionalHours > 0) {
          (workerMap[workerId]!['additional_hours'] as Map<String, double>)[dateStr] = additionalHours;
        }
        final hourPrice = (row['hour_price'] as num?)?.toDouble() ?? 0;
        if (hourPrice > 0) {
          (workerMap[workerId]!['hour_price'] as Map<String, double>)[dateStr] = hourPrice;
        }
      }
    }

    final result = workerMap.values.toList();
    print('DB GET ATTENDANCE RANGE: pivoted workers = ${result.length}');
    for (final w in result) {
      final statusKeys = w.keys.where((k) => k != 'id' && k != 'reference' && k != 'name' && k != 'full_name' && k != 'additional_hours' && k != 'hour_price').toList();
      print('  Worker ${w['id']} (${w['name']}): statusKeys=$statusKeys');
    }

    return result;
  }

  Future<String?> getLastAttendanceStatus({
    required int workerId,
    required String beforeDate,
  }) async {
    final db = await database;

    final result = await db.query(
      'attendance',
      columns: ['status'],
      where: '''
      worker_id = ?
      AND attendance_date < ?
    ''',
      whereArgs: [workerId, beforeDate],
      orderBy: 'attendance_date DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first['status']?.toString();
  }

  Future<String> generateReference(String table, String prefix) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT reference
    FROM $table
    WHERE reference LIKE '$prefix%'
    ORDER BY reference DESC
    LIMIT 1
  ''');

    if (result.isEmpty) {
      return '${prefix}001';
    }

    final lastReference = result.first['reference'] as String;

    final number = int.parse(lastReference.replaceFirst(prefix, ''));

    return '$prefix${(number + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE companies(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reference TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT
);
''');
    await db.execute('''
CREATE TABLE projects(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  company_id INTEGER NOT NULL,
  reference TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  location TEXT,
  start_date TEXT,
  end_date TEXT,
  status TEXT,
  FOREIGN KEY(company_id)
    REFERENCES companies(id)
    ON DELETE CASCADE
);
''');
    await db.execute('''
CREATE TABLE workers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reference TEXT NOT NULL UNIQUE,
  company_id INTEGER NOT NULL,
  project_id INTEGER,
  full_name TEXT NOT NULL,
  phone TEXT,
  daily_salary REAL NOT NULL,
  position TEXT,
  hire_date TEXT,
  FOREIGN KEY(company_id)
    REFERENCES companies(id)
    ON DELETE CASCADE,
  FOREIGN KEY(project_id)
    REFERENCES projects(id)
    ON DELETE SET NULL
);
''');
    await db.execute('''
CREATE TABLE attendance(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  worker_id INTEGER NOT NULL,
  project_id INTEGER,
  attendance_date TEXT NOT NULL,
  status TEXT NOT NULL,
  additional_hours REAL NOT NULL DEFAULT 0,
  hour_price REAL NOT NULL DEFAULT 0,
  UNIQUE(worker_id, attendance_date),
  FOREIGN KEY(worker_id)
    REFERENCES workers(id)
    ON DELETE CASCADE,
  FOREIGN KEY(project_id)
    REFERENCES projects(id)
    ON DELETE SET NULL
);
''');
    await db.execute('''
CREATE TABLE payroll_payments(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  worker_id INTEGER NOT NULL,
  project_id INTEGER,
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  amount_paid REAL NOT NULL DEFAULT 0,
  payment_date TEXT,
  FOREIGN KEY(worker_id)
    REFERENCES workers(id)
    ON DELETE CASCADE,
  FOREIGN KEY(project_id)
    REFERENCES projects(id)
    ON DELETE SET NULL,
  UNIQUE(worker_id, month, year)
);
''');
    await db.execute('''
CREATE TABLE settings(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: add overtime / hour-price columns to attendance.
    if (oldVersion < 2) {
      await db.execute('''
      ALTER TABLE attendance
      ADD COLUMN additional_hours REAL NOT NULL DEFAULT 0
    ''');

      await db.execute('''
      ALTER TABLE attendance
      ADD COLUMN hour_price REAL NOT NULL DEFAULT 0
    ''');
    }

    // v2 -> v3: foreign-key enforcement is enabled at runtime via `onOpen`
    // (PRAGMA foreign_keys = ON). Deleting parent rows is handled by the
    // manual cascading logic in the delete* helpers, so no schema rewrite is
    // required for existing installations.

    // v3 -> v4: introduce the key/value `settings` table used to persist
    // user preferences (theme, currency, etc.).
    if (oldVersion < 4) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''');
    }
  }

  // ------------------------------------------------------------
  // SETTINGS (key/value preferences)
  // ------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final db = await database;

    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;

    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;

    final rows = await db.query('settings');

    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  /// Copies the live database file to [destinationPath] for backup/export.
  Future<void> exportDatabase(String destinationPath) async {
    final File source = await databaseFile;
    await source.copy(destinationPath);
  }

  /// Replaces the live database file with [sourcePath] backup.
  /// Use with caution — this overwrites ALL data.
  Future<void> importDatabase(String sourcePath) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('Backup file does not exist: $sourcePath');
    }

    final File destination = await databaseFile;

    // Close the database connection before replacing the file
    final db = await database;
    await db.close();

    // Delete the WAL and SHM files if they exist
    final walFile = File('${destination.path}-wal');
    final shmFile = File('${destination.path}-shm');
    if (await walFile.exists()) {
      await walFile.delete();
    }
    if (await shmFile.exists()) {
      await shmFile.delete();
    }

    // Replace the database file
    await destination.delete();
    await source.copy(destination.path);

    // Re-initialize the database connection
    _database = null;
    await database;
  }

  // Insert a company
  Future<int> insertCompany(Map<String, dynamic> company) async {
    final db = await database;

    return await db.insert(
      'companies',
      company,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all companies
  Future<List<Map<String, dynamic>>> getCompanies() async {
    final db = await database;

    return await db.query('companies', orderBy: 'reference ASC');
  }

  Future<void> deleteCompany(int id) async {
    final db = await database;

    // Manual cascade that works regardless of the schema version: remove
    // dependent workers (and their attendance / payroll records), then
    // projects, then the company itself.
    await db.transaction((txn) async {
      final workerRows = await txn.query(
        'workers',
        columns: ['id'],
        where: 'company_id = ?',
        whereArgs: [id],
      );

      for (final row in workerRows) {
        final wid = row['id'] as int;
        await txn.delete(
          'attendance',
          where: 'worker_id = ?',
          whereArgs: [wid],
        );
        await txn.delete(
          'payroll_payments',
          where: 'worker_id = ?',
          whereArgs: [wid],
        );
      }

      await txn.delete('workers', where: 'company_id = ?', whereArgs: [id]);

      await txn.delete('projects', where: 'company_id = ?', whereArgs: [id]);

      await txn.delete('companies', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> updateCompany(Map<String, dynamic> company) async {
    final db = await database;

    return await db.update(
      'companies',
      company,
      where: 'id = ?',
      whereArgs: [company['id']],
    );
  }

  Future<int> insertProject(Map<String, dynamic> project) async {
    final db = await database;

    return await db.insert(
      'projects',
      project,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateProject(Map<String, dynamic> project) async {
    final db = await database;

    return await db.update(
      'projects',
      project,
      where: 'id = ?',
      whereArgs: [project['id']],
    );
  }

  Future<void> deleteProject(int id) async {
    final db = await database;

    // Null out project references on dependent rows (SET NULL semantics),
    // then delete the project. Works on all schema versions.
    await db.transaction((txn) async {
      await txn.update(
        'workers',
        {'project_id': null},
        where: 'project_id = ?',
        whereArgs: [id],
      );

      await txn.update(
        'attendance',
        {'project_id': null},
        where: 'project_id = ?',
        whereArgs: [id],
      );

      await txn.update(
        'payroll_payments',
        {'project_id': null},
        where: 'project_id = ?',
        whereArgs: [id],
      );

      await txn.delete('projects', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> insertWorker(Map<String, dynamic> worker) async {
    final db = await database;

    return await db.insert('workers', worker);
  }

  Future<List<Map<String, dynamic>>> getWorkers() async {
    final db = await database;

    return await db.query('workers', orderBy: 'id DESC');
  }

  Future<void> saveAttendance({
    required int workerId,
    required int? projectId,
    required String date,
    required String status,
    double additionalHours = 0,
    double hourPrice = 0,
  }) async {
    final db = await database;

    print(
      'DB SAVE ATTENDANCE: workerId=$workerId, projectId=$projectId, date=$date, status=$status, additionalHours=$additionalHours, hourPrice=$hourPrice',
    );

    // Use transaction to ensure atomicity and get affected row count
    int affectedRows = 0;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'attendance',
        where: 'worker_id = ? AND attendance_date = ?',
        whereArgs: [workerId, date],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Preserve existing additional_hours/hour_price if not explicitly provided (0 means "not changing")
        final existingAdditionalHours = (existing.first['additional_hours'] as num?)?.toDouble() ?? 0;
        final existingHourPrice = (existing.first['hour_price'] as num?)?.toDouble() ?? 0;

        final updateAdditionalHours = additionalHours > 0 ? additionalHours : existingAdditionalHours;
        final updateHourPrice = hourPrice > 0 ? hourPrice : existingHourPrice;

        affectedRows = await txn.update(
          'attendance',
          {
            'project_id': projectId,
            'status': status,
            'additional_hours': updateAdditionalHours,
            'hour_price': updateHourPrice,
          },
          where: 'worker_id = ? AND attendance_date = ?',
          whereArgs: [workerId, date],
        );
        print('DB UPDATE affectedRows=$affectedRows');
      } else {
        final insertId = await txn.insert('attendance', {
          'worker_id': workerId,
          'project_id': projectId,
          'attendance_date': date,
          'status': status,
          'additional_hours': additionalHours,
          'hour_price': hourPrice,
        });
        affectedRows = insertId > 0 ? 1 : 0;
        print('DB INSERT insertId=$insertId');
      }
    });

    if (affectedRows == 0) {
      throw Exception('Failed to save attendance: 0 rows affected');
    }

    print('DB SAVE ATTENDANCE: SUCCESS');
  }

  Future<String?> getAttendanceStatus({
    required int workerId,
    required String date,
  }) async {
    final db = await database;

    final result = await db.query(
      'attendance',
      where: 'worker_id = ? AND attendance_date = ?',
      whereArgs: [workerId, date],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first['status'] as String;
  }

  Future<List<Map<String, dynamic>>> getWorkersByProject(int projectId) async {
    final db = await database;

    return await db.query(
      'workers',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'reference',
    );
  }

  Future<int> updateWorker(Map<String, dynamic> worker) async {
    final db = await database;

    return await db.update(
      'workers',
      worker,
      where: 'id = ?',
      whereArgs: [worker['id']],
    );
  }

  Future<void> deleteWorker(int id) async {
    final db = await database;

    // Manual cascade: remove the worker's attendance / payroll records first.
    await db.transaction((txn) async {
      await txn.delete('attendance', where: 'worker_id = ?', whereArgs: [id]);

      await txn.delete(
        'payroll_payments',
        where: 'worker_id = ?',
        whereArgs: [id],
      );

      await txn.delete('workers', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getMonthlyAttendance({
    required int month,
    required int year,
    int? companyId,
    int? projectId,
    List<int>? workerIds,
  }) async {
    final db = await database;

    final monthStr = month.toString().padLeft(2, '0');
    final yearStr = year.toString();

    String whereClause = 'workers.project_id IS NOT NULL';
    final List<dynamic> args = [];

    if (companyId != null) {
      whereClause += ' AND workers.company_id = ?';
      args.add(companyId);
    }

    if (projectId != null) {
      whereClause += ' AND workers.project_id = ?';
      args.add(projectId);
    }

    if (workerIds != null && workerIds.isNotEmpty) {
      final placeholders = List.filled(workerIds.length, '?').join(',');
      whereClause += ' AND workers.id IN ($placeholders)';
      args.addAll(workerIds);
    }

    // Use LEFT JOIN with date filter in ON clause to preserve workers with no attendance
    return await db.rawQuery('''
    SELECT
      workers.id AS worker_id,
      workers.reference,
      workers.full_name,
      workers.daily_salary,

      attendance.attendance_date,
      attendance.status,
      attendance.additional_hours,
      attendance.hour_price

    FROM workers

    LEFT JOIN attendance
      ON workers.id = attendance.worker_id
      AND strftime('%m', attendance.attendance_date) = ?
      AND strftime('%Y', attendance.attendance_date) = ?

    WHERE $whereClause

    ORDER BY
      workers.reference,
      attendance.attendance_date
  ''', [monthStr, yearStr, ...args]);
  }

  Future<List<Map<String, dynamic>>> getAttendanceBetweenDates({
    required String fromDate,
    required String toDate,
    int? companyId,
    int? projectId,
    List<int>? workerIds,
  }) async {
    final db = await database;

    final from = fromDate.substring(0, 10);
    final to = toDate.substring(0, 10);

    final where = <String>['date(workers.hire_date) <= date(?)'];

    final args = <dynamic>[to];

    if (companyId != null) {
      where.add('workers.company_id = ?');
      args.add(companyId);
    }

    if (projectId != null) {
      where.add('workers.project_id = ?');
      args.add(projectId);
    }

    if (workerIds != null && workerIds.isNotEmpty) {
      final placeholders = List.filled(workerIds.length, '?').join(',');
      where.add('workers.id IN ($placeholders)');
      args.addAll(workerIds);
    }

    return await db.rawQuery(
      '''
    SELECT
      workers.id AS worker_id,
      workers.reference,
      workers.full_name,
      workers.company_id,
      workers.project_id,

      attendance.attendance_date,
      attendance.status,
      attendance.additional_hours,
      attendance.hour_price

    FROM workers

    LEFT JOIN attendance
      ON workers.id = attendance.worker_id
      AND date(attendance.attendance_date) >= date(?)
      AND date(attendance.attendance_date) <= date(?)

    WHERE ${where.join(' AND ')}

    ORDER BY
      workers.reference,
      attendance.attendance_date
    ''',
      [from, to, ...args],
    );
  }

  Future<void> savePayrollPayment({
    required int workerId,
    int? projectId,
    required int month,
    required int year,
    required double amountPaid,
  }) async {
    final db = await database;

    await db.insert('payroll_payments', {
      'worker_id': workerId,
      'project_id': projectId,
      'month': month,
      'year': year,
      'amount_paid': amountPaid,
      'payment_date': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double> getPayrollPayment({
    required int workerId,
    required int month,
    required int year,
  }) async {
    final db = await database;

    final result = await db.query(
      'payroll_payments',
      where: '''
      worker_id = ?
      AND month = ?
      AND year = ?
    ''',
      whereArgs: [workerId, month, year],
      limit: 1,
    );

    if (result.isEmpty) {
      return 0;
    }

    return (result.first['amount_paid'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getWorkersWithDetails() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT
      workers.*,
      companies.name AS company_name,
      projects.name AS project_name
    FROM workers
    LEFT JOIN companies
      ON workers.company_id = companies.id
    LEFT JOIN projects
      ON workers.project_id = projects.id
    ORDER BY workers.reference
  ''');
  }

  Future<List<Map<String, dynamic>>> getProjectsWithCompany() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT
      projects.*,
      companies.name AS company_name
    FROM projects
    LEFT JOIN companies
      ON projects.company_id = companies.id
    ORDER BY projects.reference
  ''');
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT
      projects.*,
      companies.name AS company_name
    FROM projects
    LEFT JOIN companies
      ON projects.company_id = companies.id
    ORDER BY projects.reference
  ''');
  }

  Future<List<Map<String, dynamic>>> getProjectsByCompany(int companyId) async {
    final db = await database;

    return await db.rawQuery(
      '''
    SELECT
      projects.*,
      companies.name AS company_name
    FROM projects
    LEFT JOIN companies
      ON projects.company_id = companies.id
    WHERE projects.company_id = ?
    ORDER BY projects.reference
  ''',
      [companyId],
    );
  }

  Future<List<Map<String, dynamic>>> getPayrollData({
    int? month,
    int? year,
    int? companyId,
    int? projectId,
  }) async {
    final db = await database;

    String whereClause = '1 = 1';
    List<dynamic> whereArgs = [];

    if (companyId != null) {
      whereClause += ' AND workers.company_id = ?';
      whereArgs.add(companyId);
    }

    if (projectId != null) {
      whereClause += ' AND workers.project_id = ?';
      whereArgs.add(projectId);
    }

    // Build the ON clause with date filtering to preserve LEFT JOIN semantics
    String onClause = 'ON workers.id = attendance.worker_id';
    if (month != null) {
      onClause += " AND strftime('%m', attendance.attendance_date) = ?";
      whereArgs.add(month.toString().padLeft(2, '0'));
    }
    if (year != null) {
      onClause += " AND strftime('%Y', attendance.attendance_date) = ?";
      whereArgs.add(year.toString());
    }

    // Use LOWER() for case-insensitive status comparison since stored values are lowercase
    return await db.rawQuery('''
        SELECT
          workers.id,
          workers.reference,
          workers.full_name,
          workers.daily_salary,
          workers.company_id,
          workers.project_id,

          SUM(
            CASE
              WHEN LOWER(attendance.status) = 'present' THEN 1
              ELSE 0
            END
          ) AS present_days,

          SUM(
            CASE
              WHEN LOWER(attendance.status) = 'recovery' THEN 1
              ELSE 0
            END
          ) AS recovery_days,

          SUM(
            CASE
              WHEN LOWER(attendance.status) = 'halfday' THEN 1
              ELSE 0
            END
          ) AS half_days,

          SUM(
            CASE
              WHEN LOWER(attendance.status) = 'absent' THEN 1
              ELSE 0
            END
          ) AS absent_days,

          COALESCE(SUM(attendance.additional_hours), 0) AS overtime_hours,
          COALESCE(SUM(attendance.additional_hours * attendance.hour_price), 0) AS overtime_pay

        FROM workers

        LEFT JOIN attendance
          $onClause

        WHERE $whereClause

        GROUP BY workers.id
        ORDER BY workers.reference
      ''', whereArgs);
  }

  // ------------------------------------------------------------
  // DASHBOARD SUMMARY
  // ------------------------------------------------------------

  /// Returns record counts for the main entities, used by the dashboard.
  Future<Map<String, int>> getStats() async {
    final db = await database;

    final rows = await db.rawQuery('''
    SELECT
      (SELECT COUNT(*) FROM companies) AS companies,
      (SELECT COUNT(*) FROM projects) AS projects,
      (SELECT COUNT(*) FROM workers) AS workers,
      (SELECT COUNT(*) FROM attendance) AS attendance
    ''');

    final row = rows.isNotEmpty ? rows.first : {};

    return {
      'companies': (_asInt(row['companies'])),
      'projects': (_asInt(row['projects'])),
      'workers': (_asInt(row['workers'])),
      'attendance': (_asInt(row['attendance'])),
    };
  }

  /// Workers grouped by company, for the dashboard bar chart.
  Future<List<Map<String, dynamic>>> getWorkersPerCompany() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT
      companies.name AS company,
      COUNT(workers.id) AS count
    FROM companies
    LEFT JOIN workers ON workers.company_id = companies.id
    GROUP BY companies.id
    ORDER BY companies.name
    ''');
  }

  static int _asInt(dynamic v) => (v as num?)?.toInt() ?? 0;
}

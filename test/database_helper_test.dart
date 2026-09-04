import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worker_salary_manager/database/database_helper.dart';

/// Unit tests for [DatabaseHelper].
///
/// These run entirely on the local SQLite FFI database (no device required)
/// and use an isolated temp directory so the real application database is
/// never touched.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('wsm_test_');
    DatabaseHelper.overrideDbDir = tmp.path;
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dbFile = File(p.join(tmp.path, 'salary_manager.db'));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  test('generateReference increments the numeric suffix', () async {
    final r1 =
        await DatabaseHelper.instance.generateReference('companies', 'CMP');
    expect(r1, 'CMP001');

    await DatabaseHelper.instance.insertCompany({
      'reference': r1,
      'name': 'C1',
      'address': 'A1',
      'phone': 'P1',
    });

    final r2 =
        await DatabaseHelper.instance.generateReference('companies', 'CMP');
    expect(r2, 'CMP002');
  });

  test('settings round-trip through getSetting / setSetting', () async {
    expect(await DatabaseHelper.instance.getSetting('currency'), isNull);

    await DatabaseHelper.instance.setSetting('currency', 'EUR');
    expect(await DatabaseHelper.instance.getSetting('currency'), 'EUR');

    await DatabaseHelper.instance.setSetting('currency', 'USD');
    expect(await DatabaseHelper.instance.getSetting('currency'), 'USD');
  });

  test('getStats counts the inserted entities', () async {
    final compId = await DatabaseHelper.instance.insertCompany({
      'reference': 'CMP001',
      'name': 'Acme',
      'address': '',
      'phone': '',
    });

    final projId = await DatabaseHelper.instance.insertProject({
      'company_id': compId,
      'reference': 'PRJ001',
      'name': 'Build A',
      'location': 'Site A',
      'start_date': '2024-01-01',
      'end_date': '',
      'status': 'Active',
    });

    await DatabaseHelper.instance.insertWorker({
      'reference': 'WRK001',
      'company_id': compId,
      'project_id': projId,
      'full_name': 'Bob',
      'phone': '123',
      'daily_salary': 100,
      'position': 'Mason',
      'hire_date': '2024-01-01',
    });

    final stats = await DatabaseHelper.instance.getStats();
    expect(stats['companies'], 1);
    expect(stats['projects'], 1);
    expect(stats['workers'], 1);
    expect(stats['attendance'], 0);
  });

  test('attendance save / get / last-status flow', () async {
    final compId = await DatabaseHelper.instance.insertCompany({
      'reference': 'CMP001',
      'name': 'Acme',
      'address': '',
      'phone': '',
    });
    final projId = await DatabaseHelper.instance.insertProject({
      'company_id': compId,
      'reference': 'PRJ001',
      'name': 'Build A',
      'location': '',
      'start_date': '',
      'end_date': '',
      'status': 'Active',
    });
    final workerId = await DatabaseHelper.instance.insertWorker({
      'reference': 'WRK001',
      'company_id': compId,
      'project_id': projId,
      'full_name': 'Bob',
      'phone': '',
      'daily_salary': 100,
      'position': '',
      'hire_date': '2024-01-01',
    });

    await DatabaseHelper.instance.saveAttendance(
      workerId: workerId,
      projectId: projId,
      date: '2024-06-10',
      status: 'Present',
    );

    expect(
      await DatabaseHelper.instance
          .getAttendanceStatus(workerId: workerId, date: '2024-06-10'),
      'Present',
    );

    // Recording overtime on the same day should preserve the status.
    await DatabaseHelper.instance.saveAttendance(
      workerId: workerId,
      projectId: projId,
      date: '2024-06-10',
      status: 'Present',
      additionalHours: 2.5,
    );

    expect(
      await DatabaseHelper.instance.getLastAttendanceStatus(
        workerId: workerId,
        beforeDate: '2024-06-11',
      ),
      'Present',
    );
  });

  test('deleteCompany cascades to projects / workers / attendance', () async {
    final compId = await DatabaseHelper.instance.insertCompany({
      'reference': 'CMP001',
      'name': 'Acme',
      'address': '',
      'phone': '',
    });
    final projId = await DatabaseHelper.instance.insertProject({
      'company_id': compId,
      'reference': 'PRJ001',
      'name': 'Build A',
      'location': '',
      'start_date': '',
      'end_date': '',
      'status': 'Active',
    });
    final workerId = await DatabaseHelper.instance.insertWorker({
      'reference': 'WRK001',
      'company_id': compId,
      'project_id': projId,
      'full_name': 'Bob',
      'phone': '',
      'daily_salary': 100,
      'position': '',
      'hire_date': '2024-01-01',
    });

    await DatabaseHelper.instance.saveAttendance(
      workerId: workerId,
      projectId: projId,
      date: '2024-06-10',
      status: 'Present',
    );

    await DatabaseHelper.instance.deleteCompany(compId);

    final stats = await DatabaseHelper.instance.getStats();
    expect(stats['companies'], 0);
    expect(stats['projects'], 0);
    expect(stats['workers'], 0);
    expect(stats['attendance'], 0);
  });

  test('savePayrollPayment / getPayrollPayment round-trip', () async {
    final compId = await DatabaseHelper.instance.insertCompany({
      'reference': 'CMP001',
      'name': 'Acme',
      'address': '',
      'phone': '',
    });
    final workerId = await DatabaseHelper.instance.insertWorker({
      'reference': 'WRK001',
      'company_id': compId,
      'project_id': null,
      'full_name': 'Bob',
      'phone': '',
      'daily_salary': 100,
      'position': '',
      'hire_date': '2024-01-01',
    });

    await DatabaseHelper.instance.savePayrollPayment(
      workerId: workerId,
      month: 6,
      year: 2024,
      amountPaid: 150,
    );

    expect(
      await DatabaseHelper.instance
          .getPayrollPayment(workerId: workerId, month: 6, year: 2024),
      150,
    );
  });

  test('getPayrollData aggregates attendance days', () async {
    final compId = await DatabaseHelper.instance.insertCompany({
      'reference': 'CMP001',
      'name': 'Acme',
      'address': '',
      'phone': '',
    });
    final workerId = await DatabaseHelper.instance.insertWorker({
      'reference': 'WRK001',
      'company_id': compId,
      'project_id': null,
      'full_name': 'Bob',
      'phone': '',
      'daily_salary': 1000,
      'position': '',
      'hire_date': '2024-01-01',
    });

    // 5 present days + 1 half day + 1 absent day + 1 recovery day
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-01',
        status: 'Present');
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-02',
        status: 'Present');
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-03',
        status: 'Present');
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-04',
        status: 'Present');
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-05',
        status: 'Present');
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-06',
        status: 'Half Day');
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-07',
        status: 'Absent');
    await DatabaseHelper.instance.saveAttendance(
        workerId: workerId, projectId: null, date: '2024-06-08',
        status: 'Recovery');

    final data = await DatabaseHelper.instance.getPayrollData(month: 6, year: 2024);
    expect(data, isNotEmpty);
    final row = data.first;
    expect(row['present_days'], 5);
    expect(row['half_days'], 1);
    expect(row['absent_days'], 1);
    expect(row['recovery_days'], 1);
  });

  test('exportDatabase writes a copy of the file', () async {
    await DatabaseHelper.instance.insertCompany({
      'reference': 'CMP001',
      'name': 'Acme',
      'address': '',
      'phone': '',
    });

    final dest = File(p.join(tmp.path, 'backup.db'));
    await DatabaseHelper.instance.exportDatabase(dest.path);

    expect(await dest.exists(), isTrue);
    expect(await dest.length(), greaterThan(0));
  });
}

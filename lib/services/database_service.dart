import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/database/database_helper.dart';

const Color _grey20 = Color(0xFFE8E8E8);

/// A wrapper around DatabaseHelper that catches exceptions and shows user-friendly error messages.
/// Usage: instead of calling DatabaseHelper.instance.method(), call
/// await DatabaseService.instance.method() and it will automatically handle errors.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Execute a database operation with error handling.
  /// Returns the result on success, or null on failure (error shown to user if context provided).
  Future<T?> _execute<T>(BuildContext? context, Future<T> Function() operation,
      {String? customMessage}) async {
    try {
      return await operation();
    } catch (e) {
      if (context != null && context.mounted) {
        final message = customMessage ??
            'A database error occurred. Please try again or restart the app.';
        await _showErrorDialog(context, message, e.toString());
      }
      return null;
    }
  }

  /// Execute a database operation without a BuildContext (for background operations).
  /// Returns the result on success, or null on failure (error logged but not shown to user).
  Future<T?> _executeWithoutContext<T>(Future<T> Function() operation,
      {String? customMessage}) async {
    try {
      return await operation();
    } catch (e) {
      // Log error but don't show dialog since we don't have a context
      print('Database error: ${customMessage ?? 'Unknown operation'} - $e');
      return null;
    }
  }

  Future<void> _showErrorDialog(
      BuildContext context, String message, String details) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return ContentDialog(
          title: const Text('Database Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _grey20,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  details,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        );
      },
    );
  }

  // Company operations
  Future<List<Map<String, dynamic>>?> getCompanies(BuildContext context) =>
      _execute(context, () => _db.getCompanies(),
          customMessage: 'Failed to load companies.');

  Future<int?> insertCompany(BuildContext context, Map<String, dynamic> company) =>
      _execute(context, () => _db.insertCompany(company),
          customMessage: 'Failed to save company.');

  Future<int?> updateCompany(BuildContext context, Map<String, dynamic> company) =>
      _execute(context, () => _db.updateCompany(company),
          customMessage: 'Failed to update company.');

  Future<void> deleteCompany(BuildContext context, int id) =>
      _execute(context, () => _db.deleteCompany(id),
          customMessage: 'Failed to delete company.');

  // Project operations
  Future<List<Map<String, dynamic>>?> getProjects(BuildContext context) =>
      _execute(context, () => _db.getProjects(),
          customMessage: 'Failed to load projects.');

  Future<List<Map<String, dynamic>>?> getProjectsWithCompany(BuildContext context) =>
      _execute(context, () => _db.getProjectsWithCompany(),
          customMessage: 'Failed to load projects.');

  Future<List<Map<String, dynamic>>?> getProjectsByCompany(BuildContext context, int companyId) =>
      _execute(context, () => _db.getProjectsByCompany(companyId),
          customMessage: 'Failed to load projects for selected company.');

  Future<int?> insertProject(BuildContext context, Map<String, dynamic> project) =>
      _execute(context, () => _db.insertProject(project),
          customMessage: 'Failed to save project.');

  Future<int?> updateProject(BuildContext context, Map<String, dynamic> project) =>
      _execute(context, () => _db.updateProject(project),
          customMessage: 'Failed to update project.');

  Future<void> deleteProject(BuildContext context, int id) =>
      _execute(context, () => _db.deleteProject(id),
          customMessage: 'Failed to delete project.');

  // Worker operations
  Future<List<Map<String, dynamic>>?> getWorkers(BuildContext context) =>
      _execute(context, () => _db.getWorkers(),
          customMessage: 'Failed to load workers.');

  Future<List<Map<String, dynamic>>?> getWorkersWithDetails(BuildContext context) =>
      _execute(context, () => _db.getWorkersWithDetails(),
          customMessage: 'Failed to load workers.');

  Future<List<Map<String, dynamic>>?> getWorkersByProject(BuildContext context, int projectId) =>
      _execute(context, () => _db.getWorkersByProject(projectId),
          customMessage: 'Failed to load workers for selected project.');

  Future<int?> insertWorker(BuildContext context, Map<String, dynamic> worker) =>
      _execute(context, () => _db.insertWorker(worker),
          customMessage: 'Failed to save worker.');

  Future<int?> updateWorker(BuildContext context, Map<String, dynamic> worker) =>
      _execute(context, () => _db.updateWorker(worker),
          customMessage: 'Failed to update worker.');

  Future<void> deleteWorker(BuildContext context, int id) =>
      _execute(context, () => _db.deleteWorker(id),
          customMessage: 'Failed to delete worker.');

  // Attendance operations
  Future<List<Map<String, dynamic>>?> getAttendanceRange(BuildContext context,
      {required int projectId,
      int? companyId,
      String? fromDate,
      String? toDate,
      List<int>? workerIds}) =>
      _execute(
        context,
        () => _db.getAttendanceRange(
            projectId: projectId,
            companyId: companyId,
            fromDate: fromDate,
            toDate: toDate,
            workerIds: workerIds),
        customMessage: 'Failed to load attendance data.',
      );

  Future<List<Map<String, dynamic>>?> getMonthlyAttendance(BuildContext context,
      {required int month,
      required int year,
      int? companyId,
      int? projectId,
      List<int>? workerIds}) =>
      _execute(
        context,
        () => _db.getMonthlyAttendance(
          month: month,
          year: year,
          companyId: companyId,
          projectId: projectId,
          workerIds: workerIds,
        ),
        customMessage: 'Failed to load monthly attendance.',
      );

  Future<List<Map<String, dynamic>>?> getAttendanceBetweenDates(BuildContext context,
      {required String fromDate,
      required String toDate,
      int? companyId,
      int? projectId,
      List<int>? workerIds}) =>
      _execute(
        context,
        () => _db.getAttendanceBetweenDates(
          fromDate: fromDate,
          toDate: toDate,
          companyId: companyId,
          projectId: projectId,
          workerIds: workerIds,
        ),
        customMessage: 'Failed to load attendance between dates.',
      );

  Future<bool> saveAttendance(BuildContext context,
      {required int workerId,
      required int? projectId,
      required String date,
      required String status,
      double additionalHours = 0,
      double hourPrice = 0}) async {
    try {
      await _db.saveAttendance(
        workerId: workerId,
        projectId: projectId,
        date: date,
        status: status,
        additionalHours: additionalHours,
        hourPrice: hourPrice,
      );
      print('SERVICE SAVE ATTENDANCE: SUCCESS');
      return true;
    } catch (e, stackTrace) {
      print('SERVICE SAVE ATTENDANCE ERROR: $e\n$stackTrace');
      if (context.mounted) {
        final message = 'Failed to save attendance. Please try again.';
        await _showErrorDialog(context, message, e.toString());
      }
      return false;
    }
  }

  Future<String?> getAttendanceStatus(BuildContext context,
      {required int workerId, required String date}) =>
      _execute<String?>(
        context,
        () => _db.getAttendanceStatus(workerId: workerId, date: date),
        customMessage: 'Failed to get attendance status.',
      );

  // Payroll operations
  Future<List<Map<String, dynamic>>?> getPayrollData(BuildContext context,
      {int? month,
      int? year,
      int? companyId,
      int? projectId}) =>
      _execute(
        context,
        () => _db.getPayrollData(
          month: month,
          year: year,
          companyId: companyId,
          projectId: projectId,
        ),
        customMessage: 'Failed to load payroll data.',
      );

  Future<void> savePayrollPayment(BuildContext context,
      {required int workerId,
      int? projectId,
      required int month,
      required int year,
      required double amountPaid}) =>
      _execute(
        context,
        () => _db.savePayrollPayment(
          workerId: workerId,
          projectId: projectId,
          month: month,
          year: year,
          amountPaid: amountPaid,
        ),
        customMessage: 'Failed to save payroll payment.',
      );

  Future<double?> getPayrollPayment(BuildContext context,
      {required int workerId,
      required int month,
      required int year}) =>
      _execute<double?>(
        context,
        () => _db.getPayrollPayment(
          workerId: workerId,
          month: month,
          year: year,
        ),
        customMessage: 'Failed to load payroll payment.',
      );

  // Settings operations
  Future<String?> getSetting(String key) =>
      _executeWithoutContext<String?>(() => _db.getSetting(key),
          customMessage: 'Failed to load setting.');

  Future<void> setSetting(String key, String value) =>
      _executeWithoutContext<void>(() => _db.setSetting(key, value),
          customMessage: 'Failed to save setting.');

  // Backup/Restore
  Future<void> exportDatabase(BuildContext context, String destinationPath) =>
      _execute(
        context,
        () => _db.exportDatabase(destinationPath),
        customMessage: 'Failed to export database.',
      );

  Future<void> importDatabase(BuildContext context, String sourcePath) =>
      _execute(
        context,
        () => _db.importDatabase(sourcePath),
        customMessage: 'Failed to import database. Please ensure the file is a valid backup.');

  // Dashboard stats
  Future<Map<String, int>?> getStats(BuildContext context) =>
      _execute(context, () => _db.getStats(),
          customMessage: 'Failed to load statistics.');

  Future<List<Map<String, dynamic>>?> getWorkersPerCompany(BuildContext context) =>
      _execute(context, () => _db.getWorkersPerCompany(),
          customMessage: 'Failed to load workers per company.');

  // Reference generation
  Future<String?> generateReference(BuildContext context, String table, String prefix) =>
      _execute(context, () => _db.generateReference(table, prefix),
          customMessage: 'Failed to generate reference.');
}
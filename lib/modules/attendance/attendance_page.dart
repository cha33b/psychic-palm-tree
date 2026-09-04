import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/services/database_service.dart';
import 'package:worker_salary_manager/models/company.dart';
import 'package:worker_salary_manager/models/project.dart';
import 'package:worker_salary_manager/models/attendance_status.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Color constants for consistent shading
const Color _grey10 = Color(0xFFF3F3F3);
const Color _grey20 = Color(0xFFE8E8E8);
const Color _grey40 = Color(0xFFB4B4B4);
const Color _grey60 = Color(0xFF8C8C8C);
const Color _orange10 = Color(0xFFFFF3E0);
const Color _orange40 = Color(0xFFFFB74D);
const Color _orangeText = Color(0xFFFF9800);

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Company> companies = [];
  List<Map<String, dynamic>> workers = [];
  List<Project> projects = [];

  int? selectedCompanyId;
  int? selectedProjectId;
  int? selectedWorkerId;

  // Separate month and year filters - default to current month/year
  String selectedMonth = '';
  String selectedYear = '';

  final TextEditingController _yearController = TextEditingController();

  List<DateTime> days = [];

  List<Map<String, dynamic>> rangeAttendanceData = [];
  Set<int> selectedWorkerIds = {};
  Map<int, double> attendanceOvertime = {};

  // Month options with "All"
  static const List<String> _monthOptions = [
    'All',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = _monthOptions[now.month];
    selectedYear = now.year.toString();
    _yearController.text = selectedYear;
    _init();
  }

  void _afterPointerEvent(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback();
    });
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  int? get _selectedMonthNumber {
    if (selectedMonth == 'All') return null;
    return _monthOptions.indexOf(selectedMonth);
  }

  int? get _selectedYearNumber {
    if (selectedYear == 'All') return null;
    return int.tryParse(selectedYear);
  }

  Future<void> _init() async {
    await loadCompanies();
    _updateDays();
    await loadRangeAttendance();
  }

  void _updateDays() {
    final month = _selectedMonthNumber;
    final year = _selectedYearNumber;

    if (month == null || year == null) {
      days = [];
      return;
    }

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);

    final newDays = <DateTime>[];
    DateTime current = start;

    while (!current.isAfter(end)) {
      newDays.add(current);
      current = current.add(const Duration(days: 1));
    }

    days = newDays;
  }

  void _incrementYear(int delta) {
    final current = int.tryParse(_yearController.text) ?? DateTime.now().year;
    final newYear = current + delta;

    if (newYear >= 1900 && newYear <= 2100) {
      setState(() {
        selectedYear = newYear.toString();
        _yearController.text = selectedYear;
        _updateDays();
      });

      loadRangeAttendance();
    }
  }

  void _onYearChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 1900 && parsed <= 2100) {
      setState(() {
        selectedYear = value;
        _updateDays();
      });
    }
  }

  Future<void> loadCompanies() async {
    final data = await DatabaseService.instance.getCompanies(context);
    if (!mounted) return;
    if (data == null) return;

    setState(() {
      companies = data.map((e) => Company.fromMap(e)).toList();
      if (companies.isNotEmpty) {
        selectedCompanyId = companies.first.id;
        _loadProjects(companies.first.id!);
      }
    });
  }

  Future<void> _loadProjects(int companyId) async {
    final data = await DatabaseService.instance.getProjectsByCompany(
      context,
      companyId,
    );
    if (!mounted) return;
    if (data == null) return;

    int? projectId;
    setState(() {
      projects = data.map((e) => Project.fromMap(e)).toList();
      if (projects.isNotEmpty) {
        selectedProjectId = projects.first.id;
        projectId = selectedProjectId;
      } else {
        selectedProjectId = null;
      }
    });

    if (projectId != null) {
      await _loadWorkers();
      await loadRangeAttendance();
    }
  }

  Future<void> _loadWorkers() async {
    if (selectedProjectId == null) {
      setState(() {
        workers = [];
        selectedWorkerId = null;
      });
      return;
    }

    final data = await DatabaseService.instance.getWorkersByProject(
      context,
      selectedProjectId!,
    );
    if (!mounted) return;
    if (data == null) return;

    setState(() {
      workers = data;
      selectedWorkerId = null;
    });
  }

  Future<void> loadRangeAttendance() async {
    if (selectedProjectId == null) return;

    final month = _selectedMonthNumber;
    final year = _selectedYearNumber;

    String? fromDate;
    String? toDate;

    if (month != null && year != null) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0);
      fromDate = start.toIso8601String().split('T')[0];
      toDate = end.toIso8601String().split('T')[0];
    }

    final data = await DatabaseService.instance.getAttendanceRange(
      context,
      projectId: selectedProjectId!,
      fromDate: fromDate,
      toDate: toDate,
    );

    if (!mounted) return;
    if (data == null) return;

    setState(() {
      rangeAttendanceData = data;
    });
  }

  Future<void> _printAttendanceReport() async {
    if (rangeAttendanceData.isEmpty || days.isEmpty) return;

    final pdf = pw.Document();
    final List<Map<String, dynamic>> reportWorkers = selectedWorkerId != null
        ? workers.where((w) => w['id'] == selectedWorkerId).toList()
        : workers;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text(
            'Attendance Report - ${selectedMonth != 'All' ? selectedMonth : ''} ${selectedYear != 'All' ? selectedYear : ''}'
                .trim(),
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
        build: (context) => [
          pw.Table.fromTextArray(
            headers: [
              'Date',
              ...reportWorkers.map(
                (w) => w['full_name']?.toString() ?? w['name']?.toString() ?? '',
              ),
            ],
            data: days.map((day) {
              return [
                day.day.toString(),
                ...reportWorkers.map((worker) {
                  final workerId = worker['id'] as int;
                  final status = _getStatusForWorkerDay(workerId, day);
                  final overtime = _getOvertimeForWorkerDay(workerId, day);
                  final statusDisplay = status.isEmpty ? '-' : status[0].toUpperCase();
                  final otDisplay = _formatOvertime(overtime);
                  return '$statusDisplay ($otDisplay)';
                }),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  String _getStatusForWorkerDay(int workerId, DateTime day) {
    final dateStr = day.toIso8601String().split('T')[0];
    final attendance = rangeAttendanceData.firstWhere(
      (r) => r['id'] == workerId,
      orElse: () => <String, dynamic>{},
    );
    return attendance[dateStr] as String? ?? '';
  }

  double _getOvertimeForWorkerDay(int workerId, DateTime day) {
    final dateStr = day.toIso8601String().split('T')[0];
    final workerData = rangeAttendanceData.firstWhere(
      (r) => r['id'] == workerId,
      orElse: () => <String, dynamic>{},
    );
    if (workerData.isEmpty) return 0;
    final additionalHoursMap = workerData['additional_hours'] as Map<String, double>?;
    if (additionalHoursMap == null) return 0;
    return additionalHoursMap[dateStr] ?? 0;
  }

  String _formatOvertime(double hours) {
    if (hours == hours.roundToDouble()) {
      return hours.toInt().toString();
    }
    return hours.toString();
  }

  // ----- FILTER BAR -----

  List<ComboBoxItem<int?>> _buildCompanyItems() {
    final items = <ComboBoxItem<int?>>[
      const ComboBoxItem<int?>(value: null, child: Text('All')),
    ];
    for (final c in companies) {
      items.add(ComboBoxItem<int?>(
        value: c.id,
        child: Text('${c.reference} - ${c.name}'),
      ));
    }
    return items;
  }

  List<ComboBoxItem<int?>> _buildProjectItems() {
    final items = <ComboBoxItem<int?>>[
      const ComboBoxItem<int?>(value: null, child: Text('All')),
    ];
    for (final p in projects) {
      items.add(ComboBoxItem<int?>(
        value: p.id,
        child: Text('${p.reference} - ${p.name}'),
      ));
    }
    return items;
  }

  List<ComboBoxItem<int?>> _buildWorkerItems() {
    final items = <ComboBoxItem<int?>>[
      const ComboBoxItem<int?>(value: null, child: Text('All')),
    ];
    for (final w in workers) {
      items.add(ComboBoxItem<int?>(
        value: w['id'] as int,
        child: Text(w['full_name']?.toString() ?? w['name']?.toString() ?? ''),
      ));
    }
    return items;
  }

  List<ComboBoxItem<String>> _buildMonthItems() {
    return _monthOptions
        .map((m) => ComboBoxItem<String>(value: m, child: Text(m)))
        .toList();
  }

  Widget _buildYearInput() {
    return SizedBox(
      width: 220,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(FluentIcons.chevron_up),
            onPressed: () => _incrementYear(1),
          ),
          SizedBox(
            width: 80,
            child: TextBox(
              controller: _yearController,
              placeholder: 'Year',
              onSubmitted: _onYearChanged,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.chevron_down),
            onPressed: () => _incrementYear(-1),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      height: 70,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: _grey20,
        border: Border(bottom: BorderSide(color: _grey40)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: ComboBox<int?>(
                placeholder: const Text('Company'),
                value: selectedCompanyId,
                items: _buildCompanyItems(),
                onChanged: (value) {
                  _afterPointerEvent(() async {
                    setState(() {
                      selectedCompanyId = value;
                      selectedProjectId = null;
                      selectedWorkerId = null;
                      workers = [];
                      projects = [];
                      rangeAttendanceData = [];
                      days = [];
                    });
                    if (value != null) {
                      await _loadProjects(value);
                    } else {
                      _updateDays();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: ComboBox<int?>(
                placeholder: const Text('Project'),
                value: selectedProjectId,
                items: _buildProjectItems(),
                onChanged: (value) {
                  _afterPointerEvent(() async {
                    setState(() {
                      selectedProjectId = value;
                      selectedWorkerId = null;
                      workers = [];
                      rangeAttendanceData = [];
                    });
                    if (value != null) {
                      await _loadWorkers();
                      await loadRangeAttendance();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: ComboBox<int?>(
                placeholder: const Text('Worker'),
                value: selectedWorkerId,
                items: _buildWorkerItems(),
                onChanged: (value) {
                  setState(() {
                    selectedWorkerId = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: ComboBox<String>(
                placeholder: const Text('Month'),
                value: selectedMonth,
                items: _buildMonthItems(),
                onChanged: (value) {
                  if (value == null) return;
                  _afterPointerEvent(() {
                    setState(() {
                      selectedMonth = value;
                      _updateDays();
                    });
                    loadRangeAttendance();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            _buildYearInput(),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: loadRangeAttendance,
              child: const Text('Load'),
            ),
          ],
        ),
      ),
    );
  }

  // ----- ATTENDANCE CELL -----

  Widget _buildAttendanceCell(int workerId, DateTime day) {
    const double cellWidth = 140.0;
    const double cellHeight = 50.0;

    final status = _getStatusForWorkerDay(workerId, day);
    final color = _getStatusColor(status);
    final overtime = _getOvertimeForWorkerDay(workerId, day);
    final overtimeText = _formatOvertime(overtime);

    return SizedBox(
      width: cellWidth,
      height: cellHeight,
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 36,
            child: GestureDetector(
              onTap: () => _showAttendanceDialog(workerId, day),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  status.isEmpty ? '-' : status[0].toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => _showOTDialog(workerId, day),
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _orange10,
                  border: Border.all(color: _orange40),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  overtimeText,
                  style: const TextStyle(
                    color: _orangeText,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- ATTENDANCE DIALOG (save inside dialog) -----

  Future<void> _showAttendanceDialog(int workerId, DateTime day) async {
    final currentStatus = _getStatusForWorkerDay(workerId, day);
    final TextEditingController controller = TextEditingController(
      text: currentStatus,
    );

    await showDialog<String>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text('Set Attendance for ${day.day}/${day.month}/${day.year}'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedValue = controller.text.isEmpty ? null : controller.text;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ComboBox<String>(
                  value: selectedValue,
                  items: const [
                    AttendanceStatus.present,
                    AttendanceStatus.absent,
                    AttendanceStatus.halfDay,
                    AttendanceStatus.recovery,
                  ]
                      .map((s) => ComboBoxItem(value: s.name, child: Text(s.name)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      controller.text = value ?? '';
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final statusValue = controller.text.trim();
              if (statusValue.isEmpty) {
                displayInfoBar(
                  dialogContext,
                  builder: (context, close) => const InfoBar(
                    title: Text('No Status Selected'),
                    content: Text('Please select an attendance status.'),
                    severity: InfoBarSeverity.warning,
                  ),
                );
                return;
              }

              if (statusValue == currentStatus) {
                // No change, just close
                Navigator.pop(dialogContext);
                return;
              }

              if (selectedProjectId == null) {
                displayInfoBar(
                  dialogContext,
                  builder: (context, close) => const InfoBar(
                    title: Text('No Project'),
                    content: Text('Please select a project first.'),
                    severity: InfoBarSeverity.warning,
                  ),
                );
                return;
              }

              final dateStr = day.toIso8601String().split('T')[0];
              final dbService = DatabaseService.instance;

              print(
                'SAVE ATTENDANCE: workerId=$workerId, projectId=$selectedProjectId, date=$dateStr, status=$statusValue',
              );

              final success = await dbService.saveAttendance(
                dialogContext,
                workerId: workerId,
                projectId: selectedProjectId,
                date: dateStr,
                status: statusValue,
              );

              print('SAVE RESULT: success=$success');

              if (success) {
                // Close dialog first, then refresh
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await loadRangeAttendance();
              } else {
                // Keep dialog open, show error
                if (dialogContext.mounted) {
                  displayInfoBar(
                    dialogContext,
                    builder: (context, close) => const InfoBar(
                      title: Text('Save Failed'),
                      content: Text('Could not save attendance. Please try again.'),
                      severity: InfoBarSeverity.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ----- OT DIALOG (save inside dialog) -----

  Future<void> _showOTDialog(int workerId, DateTime day) async {
    final dateStr = day.toIso8601String().split('T')[0];

    // Get current OT hours for this day from pivoted data
    double currentOT = 0;
    final workerData = rangeAttendanceData
        .where((r) => r['id'] == workerId)
        .firstOrNull;
    if (workerData != null) {
      final additionalHoursMap =
          workerData['additional_hours'] as Map<String, double>?;
      if (additionalHoursMap != null && additionalHoursMap[dateStr] != null) {
        currentOT = additionalHoursMap[dateStr]!;
      }
    }

    final otController = TextEditingController(text: currentOT.toString());
    final hourPriceController = TextEditingController();

    await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text('Set OT for ${day.day}/${day.month}/${day.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextBox(controller: otController, placeholder: 'OT Hours'),
            const SizedBox(height: 12),
            TextBox(
              controller: hourPriceController,
              placeholder: 'Hour Price (optional)',
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final hours = double.tryParse(otController.text) ?? 0;
              final hourPrice = double.tryParse(hourPriceController.text) ?? 0;

              if (selectedProjectId == null) {
                displayInfoBar(
                  dialogContext,
                  builder: (context, close) => const InfoBar(
                    title: Text('No Project'),
                    content: Text('Please select a project first.'),
                    severity: InfoBarSeverity.warning,
                  ),
                );
                return;
              }

              final success = await DatabaseService.instance.saveAttendance(
                dialogContext,
                workerId: workerId,
                projectId: selectedProjectId,
                date: dateStr,
                status: 'present',
                additionalHours: hours,
                hourPrice: hourPrice,
              );

              if (success) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await loadRangeAttendance();
              } else {
                if (dialogContext.mounted) {
                  displayInfoBar(
                    dialogContext,
                    builder: (context, close) => const InfoBar(
                      title: Text('Save Failed'),
                      content: Text('Could not save overtime. Please try again.'),
                      severity: InfoBarSeverity.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ----- GRID -----

  Widget _buildAttendanceGrid() {
    if (selectedProjectId == null) {
      return const Center(child: Text('Select a project to view attendance'));
    }

    if (days.isEmpty) {
      return const Center(
        child: Text(
          'Select both Month and Year to view attendance calendar',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final List<Map<String, dynamic>> displayWorkers = selectedWorkerId != null
        ? workers.where((w) => w['id'] == selectedWorkerId).toList()
        : workers;

    if (displayWorkers.isEmpty) {
      return const Center(
        child: Text(
          'No workers found for the selected project.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    const double colDateWidth = 100.0;
    const double colWorkerWidth = 160.0;
    final double totalWidth =
        colDateWidth + (displayWorkers.length * colWorkerWidth);

    // Header cells
    final headerCells = <Widget>[
      const SizedBox(
        width: colDateWidth,
        height: 40,
        child: Center(
          child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      for (final worker in displayWorkers)
        SizedBox(
          width: colWorkerWidth,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  worker['full_name']?.toString() ??
                      worker['name']?.toString() ??
                      '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  worker['reference']?.toString() ?? '',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
    ];

    // Data rows — one per day
    final dataRows = <Widget>[];
    for (final day in days) {
      final rowCells = <Widget>[
        SizedBox(
          width: colDateWidth,
          height: 50,
          child: Center(
            child: Text(
              day.day.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        for (final worker in displayWorkers)
          _buildAttendanceCell(worker['id'] as int, day),
      ];

      dataRows.add(
        SizedBox(
          width: totalWidth,
          height: 50,
          child: Row(children: rowCells),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 500;
        final double headerHeight = 40.0;
        final double dataHeight = availableHeight - headerHeight;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: headerHeight,
                  decoration: BoxDecoration(
                    border: Border.all(color: _grey60),
                    color: _grey20,
                  ),
                  child: Row(children: headerCells),
                ),
                SizedBox(
                  height: dataHeight,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: dataRows,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'half_day':
        return Colors.orange;
      case 'recovery':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Attendance'),
        commandBar: Row(
          children: [
            FilledButton(
              onPressed: _printAttendanceReport,
              child: const Text('Print Report'),
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: _buildAttendanceGrid(),
            ),
          ),
        ],
      ),
    );
  }
}
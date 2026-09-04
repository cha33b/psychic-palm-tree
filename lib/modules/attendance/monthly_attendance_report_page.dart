import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:worker_salary_manager/database/database_helper.dart';

const Color _grey20 = Color(0xFFE8E8E8);
const Color _grey30 = Color(0xFFD0D0D0);

class MonthlyAttendanceReportPage extends StatefulWidget {
  const MonthlyAttendanceReportPage({super.key});

  @override
  State<MonthlyAttendanceReportPage> createState() =>
      _MonthlyAttendanceReportPageState();
}

class _MonthlyAttendanceReportPageState
    extends State<MonthlyAttendanceReportPage> {
  DateTime fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime toDate = DateTime.now();

  List<Map<String, dynamic>> attendanceData = [];

  bool loading = false;

  // We will use these later for worker selection.
  Set<int> selectedWorkerIds = {};
  bool selectAllWorkers = true;

  // ------------------------------------------------------------
  // LOAD REPORT
  // ------------------------------------------------------------

  Future<void> loadReport() async {
    if (fromDate.isAfter(toDate)) {
      displayInfoBar(
        context,
        builder: (context, close) {
          return const InfoBar(
            title: Text('Invalid date range'),
            content: Text('From Date cannot be after To Date.'),
            severity: InfoBarSeverity.error,
          );
        },
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final data = await DatabaseHelper.instance.getAttendanceBetweenDates(
        fromDate: fromDate.toIso8601String(),
        toDate: toDate.toIso8601String(),
      );

      if (!mounted) return;

      setState(() {
        attendanceData = data;
      });
    } catch (e) {
      if (!mounted) return;

      displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('Error'),
            content: Text(e.toString()),
            severity: InfoBarSeverity.error,
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // DATE HELPERS
  // ------------------------------------------------------------

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  List<DateTime> getReportDates() {
    final dates = <DateTime>[];

    DateTime current = DateTime(fromDate.year, fromDate.month, fromDate.day);

    final end = DateTime(toDate.year, toDate.month, toDate.day);

    while (!current.isAfter(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  String dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String statusCode(String? status) {
    switch (status) {
      case 'Present':
        return 'P';

      case 'Recovery':
        return 'R';

      case 'Half Day':
        return 'HD';

      case 'Absent':
        return 'A';

      default:
        return '';
    }
  }

  // ------------------------------------------------------------
  // PRINT
  // ------------------------------------------------------------

  Future<void> printReport() async {
    if (attendanceData.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) {
          return const InfoBar(
            title: Text('No attendance'),
            content: Text('Generate the attendance report first.'),
            severity: InfoBarSeverity.warning,
          );
        },
      );

      return;
    }

    await Printing.layoutPdf(
      onLayout: (format) async {
        return buildPdf(format);
      },
    );
  }

  // ------------------------------------------------------------
  // BUILD PDF
  // ------------------------------------------------------------

  Future<Uint8List> buildPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    final reportDates = getReportDates();

    // Group attendance by worker.
    final Map<int, List<Map<String, dynamic>>> workers = {};

    for (final row in attendanceData) {
      final workerId = row['worker_id'] as int;

      workers.putIfAbsent(workerId, () => []);

      workers[workerId]!.add(row);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return [
            pw.Text(
              'MONTHLY ATTENDANCE',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 5),

            pw.Text(
              '${formatDate(fromDate)} - ${formatDate(toDate)}',
              style: const pw.TextStyle(fontSize: 12),
            ),

            pw.SizedBox(height: 15),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),

              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,

              columnWidths: {
                // Ref
                0: const pw.FixedColumnWidth(48),

                // Worker
                1: const pw.FixedColumnWidth(90),

                // Dates
                for (int i = 0; i < reportDates.length; i++)
                  i + 2: const pw.FixedColumnWidth(18),

                // Totals
                reportDates.length + 2: const pw.FixedColumnWidth(30), // P&R

                reportDates.length + 3: const pw.FixedColumnWidth(30), // HD

                reportDates.length + 4: const pw.FixedColumnWidth(30), // A

                reportDates.length + 5: const pw.FixedColumnWidth(40), // OT
              },

              children: [
                // ------------------------------------------------
                // HEADER
                // ------------------------------------------------
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pdfHeader('Ref'),
                    pdfHeader('Worker'),

                    for (final date in reportDates)
                      pdfHeader(
                        '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}',
                      ),

                    pdfHeader('P&R'),
                    pdfHeader('HD'),
                    pdfHeader('A'),
                    pdfHeader('OT'),
                  ],
                ),

                // ------------------------------------------------
                // WORKERS
                // ------------------------------------------------
                for (final workerRows in workers.values)
                  ...buildWorkerRows(workerRows, reportDates),
              ],
            ),
          ];
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  // ------------------------------------------------------------
  // PDF WORKER ROWS
  // ------------------------------------------------------------

  List<pw.TableRow> buildWorkerRows(
    List<Map<String, dynamic>> rows,
    List<DateTime> reportDates,
  ) {
    final first = rows.first;

    final Map<String, Map<String, dynamic>> byDate = {};

    for (final row in rows) {
      final date = DateTime.parse(row['attendance_date'].toString());

      byDate[dateKey(date)] = row;
    }

    int presentRecovery = 0;
    int halfDay = 0;
    int absent = 0;
    double overtime = 0;

    for (final row in rows) {
      final status = row['status']?.toString();

      if (status == 'Present' || status == 'Recovery') {
        presentRecovery++;
      } else if (status == 'Half Day') {
        halfDay++;
      } else if (status == 'Absent') {
        absent++;
      }

      overtime += ((row['additional_hours'] ?? 0) as num).toDouble();
    }

    return [
      // ----------------------------------------------------------
      // ATTENDANCE ROW
      // ----------------------------------------------------------
      pw.TableRow(
        children: [
          pdfCell(first['reference']?.toString() ?? '', bold: true),

          pdfCell(first['full_name']?.toString() ?? '', bold: true),

          for (final date in reportDates)
            pdfCell(
              statusCode(byDate[dateKey(date)]?['status']?.toString()),
              center: true,
            ),

          pdfCell(presentRecovery.toString(), center: true, bold: true),

          pdfCell(halfDay.toString(), center: true, bold: true),

          pdfCell(absent.toString(), center: true, bold: true),

          pdfCell(overtime.toStringAsFixed(1), center: true, bold: true),
        ],
      ),

      // ----------------------------------------------------------
      // OT HOURS ROW
      // ----------------------------------------------------------
      pw.TableRow(
        children: [
          pdfCell(''),

          pdfCell('OT Hours', italic: true),

          for (final date in reportDates)
            pdfCell(
              byDate[dateKey(date)] == null
                  ? ''
                  : ((byDate[dateKey(date)]!['additional_hours'] ?? 0) as num)
                            .toDouble() ==
                        0
                  ? ''
                  : ((byDate[dateKey(date)]!['additional_hours'] ?? 0) as num)
                        .toDouble()
                        .toStringAsFixed(1),
              center: true,
            ),

          pdfCell(''),
          pdfCell(''),
          pdfCell(''),
          pdfCell(''),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------
  // PDF HEADER CELL
  // ------------------------------------------------------------

  pw.Widget pdfHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  // ------------------------------------------------------------
  // PDF NORMAL CELL
  // ------------------------------------------------------------

  pw.Widget pdfCell(
    String text, {
    bool center = false,
    bool bold = false,
    bool italic = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    loadReport();
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('Monthly Attendance')),

      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                // ----------------------------------------------
                // FROM DATE
                // ----------------------------------------------
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('From Date'),

                    const SizedBox(height: 5),

                    SizedBox(
                      width: 170,
                      child: DatePicker(
                        selected: fromDate,
                        onChanged: (date) {
                          setState(() {
                            fromDate = date;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 10),

                // ----------------------------------------------
                // TO DATE
                // ----------------------------------------------
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('To Date'),

                    const SizedBox(height: 5),

                    SizedBox(
                      width: 170,
                      child: DatePicker(
                        selected: toDate,
                        onChanged: (date) {
                          setState(() {
                            toDate = date;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 10),

                // ----------------------------------------------
                // GENERATE
                // ----------------------------------------------
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          await loadReport();
                        },
                  child: const Text('Generate'),
                ),

                const SizedBox(width: 10),

                // ----------------------------------------------
                // PRINT
                // ----------------------------------------------
                Button(
                  onPressed: attendanceData.isEmpty
                      ? null
                      : () async {
                          await printReport();
                        },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.print, size: 16),
                      SizedBox(width: 8),
                      Text('Print'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // ----------------------------------------------------
          // REPORT
          // ----------------------------------------------------
          Expanded(
            child: attendanceData.isEmpty
                ? const Center(child: Text('No attendance records.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(child: buildPreview()),
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SCREEN PREVIEW
  // ------------------------------------------------------------

  Widget buildPreview() {
    final reportDates = getReportDates();

    final Map<int, List<Map<String, dynamic>>> workers = {};

    for (final row in attendanceData) {
      final workerId = row['worker_id'] as int;

      workers.putIfAbsent(workerId, () => []);

      workers[workerId]!.add(row);
    }

    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------
          // HEADER
          // ----------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            color: _grey20,
            child: Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Ref',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(
                  width: 180,
                  child: Text(
                    'Worker',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                for (final date in reportDates)
                  SizedBox(
                    width: 45,
                    child: Center(
                      child: Text(
                        '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(
                  width: 45,
                  child: Center(
                    child: Text(
                      'P&R',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 45,
                  child: Center(
                    child: Text(
                      'HD',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 45,
                  child: Center(
                    child: Text(
                      'A',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 60,
                  child: Center(
                    child: Text(
                      'OT',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // ----------------------------------------------------
          // WORKERS
          // ----------------------------------------------------
          for (final workerRows in workers.values)
            buildWorkerPreview(workerRows, reportDates),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SCREEN WORKER ROW
  // ------------------------------------------------------------

  Widget buildWorkerPreview(
    List<Map<String, dynamic>> rows,
    List<DateTime> reportDates,
  ) {
    final first = rows.first;

    final Map<String, Map<String, dynamic>> byDate = {};

    for (final row in rows) {
      final date = DateTime.parse(row['attendance_date'].toString());

      byDate[dateKey(date)] = row;
    }

    int presentRecovery = 0;
    int halfDay = 0;
    int absent = 0;
    double overtime = 0;

    for (final row in rows) {
      final status = row['status']?.toString();

      if (status == 'Present' || status == 'Recovery') {
        presentRecovery++;
      } else if (status == 'Half Day') {
        halfDay++;
      } else if (status == 'Absent') {
        absent++;
      }

      overtime += ((row['additional_hours'] ?? 0) as num).toDouble();
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: _grey30)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // ----------------------------------------------------
          // ATTENDANCE ROW
          // ----------------------------------------------------
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    first['reference']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              SizedBox(
                width: 180,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(first['full_name']?.toString() ?? ''),
                ),
              ),

              for (final date in reportDates)
                SizedBox(
                  width: 45,
                  child: Center(
                    child: Text(
                      statusCode(byDate[dateKey(date)]?['status']?.toString()),
                    ),
                  ),
                ),

              SizedBox(
                width: 45,
                child: Center(child: Text(presentRecovery.toString())),
              ),

              SizedBox(
                width: 45,
                child: Center(child: Text(halfDay.toString())),
              ),

              SizedBox(
                width: 45,
                child: Center(child: Text(absent.toString())),
              ),

              SizedBox(
                width: 60,
                child: Center(child: Text(overtime.toStringAsFixed(1))),
              ),
            ],
          ),

          // ----------------------------------------------------
          // OT HOURS ROW
          // ----------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                const SizedBox(width: 90),

                const SizedBox(
                  width: 180,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'OT Hours',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),

                for (final date in reportDates)
                  SizedBox(
                    width: 45,
                    child: Center(
                      child: Text(
                        byDate[dateKey(date)] == null
                            ? ''
                            : ((byDate[dateKey(date)]!['additional_hours'] ?? 0)
                                      as num)
                                  .toDouble()
                                  .toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),

                const SizedBox(width: 45),
                const SizedBox(width: 45),
                const SizedBox(width: 45),
                const SizedBox(width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

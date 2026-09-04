import 'package:fl_chart/fl_chart.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:worker_salary_manager/database/database_helper.dart';

/// The actual content shown on the "Dashboard" navigation item.
///
/// Displays high-level summary stats (counts of companies, projects, workers
/// and attendance records) and a bar chart of workers per company.
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Map<String, int> stats = {};
  List<Map<String, dynamic>> perCompany = [];
  String todayLabel = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await DatabaseHelper.instance.getStats();
    final pc = await DatabaseHelper.instance.getWorkersPerCompany();

    if (!mounted) return;

    setState(() {
      stats = s;
      perCompany = pc;
      todayLabel = DateFormat.yMMMMd().format(DateTime.now());
      loading = false;
    });
  }

  int _maxBar() {
    if (perCompany.isEmpty) return 1;
    var m = 0.0;
    for (final e in perCompany) {
      final c = (e['count'] as num).toDouble();
      if (c > m) m = c;
    }
    final rounded = m.ceil();
    return rounded < 1 ? 1 : rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const ScaffoldPage(
        header: PageHeader(title: Text('Dashboard')),
        content: Center(child: ProgressRing()),
      );
    }

    final accent = FluentTheme.of(context).accentColor;
    final maxBar = _maxBar();
    final labels = perCompany
        .map((e) => (e['company'] as String?) ?? '')
        .toList();

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Dashboard'),
        commandBar: Text(todayLabel),
      ),
      content: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard('Companies', stats['companies'] ?? 0, FluentIcons.bank, accent),
              _StatCard('Projects', stats['projects'] ?? 0, FluentIcons.build, accent),
              _StatCard('Workers', stats['workers'] ?? 0, FluentIcons.people, accent),
              _StatCard(
                'Attendance records',
                stats['attendance'] ?? 0,
                FluentIcons.calendar,
                accent,
              ),
            ],
          ),

          const SizedBox(height: 32),

          const Text(
            'Workers per company',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (perCompany.isEmpty)
            const Text('No companies yet.')
          else
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Color(0xFFE0E0E0), strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[i],
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(labels.length, (i) {
                    final count = (perCompany[i]['count'] as num).toDouble();
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: count,
                          width: 18,
                          color: accent.normal,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                  maxY: maxBar.toDouble(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final AccentColor color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
    );
  }
}

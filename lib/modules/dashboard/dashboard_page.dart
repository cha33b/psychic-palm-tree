import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/modules/companies/companies_page.dart';
import 'package:worker_salary_manager/modules/workers/workers_page.dart';
import 'package:worker_salary_manager/modules/projects/projects_page.dart';
import 'package:worker_salary_manager/modules/attendance/attendance_page.dart';
import 'package:worker_salary_manager/modules/attendance/monthly_attendance_report_page.dart';
import 'package:worker_salary_manager/modules/dashboard/dashboard_home.dart';
import 'package:worker_salary_manager/modules/payroll/payroll_page.dart';
import 'package:worker_salary_manager/modules/settings/settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      pane: NavigationPane(
        selected: selected,
        onChanged: (index) {
          setState(() {
            selected = index;
          });
        },
        displayMode: PaneDisplayMode.expanded,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('Dashboard'),
            body: const DashboardHome(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.people),
            title: const Text('Companies'),
            body: CompaniesPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.build),
            title: const Text('Projects'),
            body: const ProjectsPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.people),
            title: const Text('Workers'),
            body: const WorkersPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.calendar),
            title: const Text('Attendance'),
            body: const AttendancePage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.money),
            title: const Text('Payroll'),
            body: PayrollPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.report_document),
            title: const Text('Reports'),
            body: const MonthlyAttendanceReportPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('Settings'),
            body: const SettingsPage(),
          ),
        ],
      ),
    );
  }
}

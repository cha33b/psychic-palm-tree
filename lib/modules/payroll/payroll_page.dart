import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/models/company.dart';
import 'package:worker_salary_manager/models/project.dart';
import 'package:worker_salary_manager/services/database_service.dart';
import 'package:worker_salary_manager/modules/settings/settings_service.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  List<Map<String, dynamic>> payrollData = [];
  Map<int, double> paidAmounts = {};

  List<Company> companies = [];
  List<Project> projects = [];

  int? selectedCompanyId;
  int? selectedProjectId;

  int selectedMonth = 0;
  int selectedYear = 0;

  Future<void> generatePayroll() async {
      final data = await DatabaseService.instance.getPayrollData(
        context,
        month: selectedMonth == 0 ? null : selectedMonth,
        year: selectedYear == 0 ? null : selectedYear,
        companyId: selectedCompanyId,
        projectId: selectedProjectId,
      );

    setState(() {
          payrollData = data ?? [];
          paidAmounts = {};
        });

    await loadPayments();
  }

  Future<void> showPaymentDialog(
    Map<String, dynamic> worker,
    double totalSalary,
  ) async {
    final workerId = worker['id'] as int;

    final currentPaid = paidAmounts[workerId] ?? 0;

    final controller = TextEditingController(
      text: currentPaid.toStringAsFixed(2),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return ContentDialog(
          title: Text("Payment - ${worker['full_name']}"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total salary: ${totalSalary.toStringAsFixed(2)} ${SettingsService.instance.currency.value}"),

              const SizedBox(height: 15),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Amount Paid",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextBox(controller: controller, placeholder: "Enter amount"),
                ],
              ),
            ],
          ),

          actions: [
            Button(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
            ),

            FilledButton(
              child: const Text("Save Payment"),
              onPressed: () async {
                final amount = double.tryParse(controller.text.trim());

                if (amount == null || amount < 0) {
                  displayInfoBar(
                    dialogContext,
                    builder: (context, close) {
                      return const InfoBar(
                        title: Text("Invalid amount"),
                        content: Text("Please enter a valid payment amount."),
                        severity: InfoBarSeverity.error,
                      );
                    },
                  );

                  return;
                }

                if (amount > totalSalary) {
                  displayInfoBar(
                    dialogContext,
                    builder: (context, close) {
                      return const InfoBar(
                        title: Text("Invalid payment"),
                        content: Text(
                          "Payment cannot be greater than the total salary.",
                        ),
                        severity: InfoBarSeverity.warning,
                      );
                    },
                  );

                  return;
                }

                if (selectedMonth == 0 || selectedYear == 0) {
                                    displayInfoBar(
                                      dialogContext,
                                      builder: (context, close) => const InfoBar(
                                        title: Text("Invalid selection"),
                                        content: Text("Please select a specific month and year."),
                                        severity: InfoBarSeverity.warning,
                                      ),
                                    );
                                    return;
                                  }

                                  await DatabaseService.instance.savePayrollPayment(
                                                                      context,
                                                                      workerId: workerId,
                                                                      projectId: worker['project_id'],
                                                                      month: selectedMonth,
                                                                      year: selectedYear,
                                                                      amountPaid: amount,
                                                                    );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      await loadPayments();
    }
  }

  Future<void> loadCompanies() async {
      final data = await DatabaseService.instance.getCompanies(context);

      if (data == null) return;

      setState(() {
        companies = data.map((e) => Company.fromMap(e)).toList();
      });
    }

  @override
  void initState() {
    super.initState();

    loadCompanies();

    selectedMonth = 0;
    selectedYear = 0;
  }

  Future<void> loadPayments() async {
        if (selectedMonth == 0 || selectedYear == 0) {
          return;
        }

        final Map<int, double> payments = {};

        for (final worker in payrollData) {
          final workerId = worker['id'] as int;

          final amount = await DatabaseService.instance.getPayrollPayment(
            context,
            workerId: workerId,
            month: selectedMonth,
            year: selectedYear,
          );

          payments[workerId] = amount ?? 0;
        }

        if (mounted) {
          setState(() {
            paidAmounts = payments;
          });
        }
      }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text("Payroll")),

      content: ValueListenableBuilder<String>(
        valueListenable: SettingsService.instance.currency,
        builder: (context, currency, child) {
          return Column(
            children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: ComboBox<int>(
                    value: selectedCompanyId ?? -1,
                    isExpanded: true,
                    placeholder: const Text("Company"),

                    items: [
                      const ComboBoxItem<int>(
                        value: -1,
                        child: Text("All Companies"),
                      ),

                      ...companies.map((company) {
                        return ComboBoxItem<int>(
                          value: company.id!,
                          child: SizedBox(
                            width: 220,
                            child: Text(
                              "${company.reference} - ${company.name}",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        );
                      }),
                    ],

                    onChanged: (value) async {
                                          setState(() {
                                            selectedCompanyId = value == -1 ? null : value;
                                            selectedProjectId = null;
                                            projects.clear();
                                          });

                                          if (value != null && value != -1) {
                                            final data = await DatabaseService.instance.getProjectsByCompany(context, value);

                                            if (data == null) return;

                                            setState(() {
                                              projects = data
                                                  .map((e) => Project.fromMap(e))
                                                  .toList();
                                            });
                                          } else {
                                            final data = await DatabaseService.instance.getProjects(context);

                                            if (data == null) return;

                                            setState(() {
                                              projects = data
                                                  .map((e) => Project.fromMap(e))
                                                  .toList();
                                            });
                                          }
                                        },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ComboBox<int>(
                    value: selectedProjectId ?? -1,
                    isExpanded: true,
                    placeholder: const Text("Project"),

                    items: [
                      const ComboBoxItem<int>(
                        value: -1,
                        child: Text("All Projects"),
                      ),

                      ...projects.map((project) {
                        return ComboBoxItem<int>(
                          value: project.id!,
                          child: SizedBox(
                            width: 220,
                            child: Text(
                              "${project.reference} - ${project.name}",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        );
                      }),
                    ],

                    onChanged: (value) {
                      setState(() {
                        selectedProjectId = value == -1 ? null : value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ComboBox<int>(
                    value: selectedMonth,
                    isExpanded: true,

                    items: [
                      const ComboBoxItem<int>(
                        value: 0,
                        child: Text("All Months"),
                      ),

                      ...List.generate(12, (index) {
                        final month = index + 1;

                        final monthName = [
                          "January",
                          "February",
                          "March",
                          "April",
                          "May",
                          "June",
                          "July",
                          "August",
                          "September",
                          "October",
                          "November",
                          "December",
                        ][index];

                        return ComboBoxItem<int>(
                          value: month,
                          child: Text(monthName),
                        );
                      }),
                    ],

                    onChanged: (value) {
                                          setState(() {
                                            selectedMonth = value ?? 0;
                                          });
                                        },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ComboBox<int>(
                    value: selectedYear,
                    isExpanded: true,

                    items: [
                      const ComboBoxItem<int>(
                        value: 0,
                        child: Text("All Years"),
                      ),

                      ...List.generate(10, (index) {
                        final year = DateTime.now().year - index;

                        return ComboBoxItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        );
                      }),
                    ],

                    onChanged: (value) {
                                          setState(() {
                                            selectedYear = value ?? 0;
                                          });
                                        },
                  ),
                ),

                const SizedBox(width: 15),

                FilledButton(
                  child: const Text("Generate Payroll"),
                  onPressed: () async {
                    await generatePayroll();
                  },
                ),
              ],
            ),
          ),

          const Divider(),

          const Divider(),

          Expanded(
            child: payrollData.isEmpty
                ? const Center(
                    child: Text(
                      "No payroll generated.",
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 1050,
                      child: ListView(
                        padding: const EdgeInsets.all(15),
                        children: [
                          // TABLE HEADER
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    "N°",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    "Ref",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    "Worker",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    "Present",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    "Recovery",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    "Half Day",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                                                  width: 80,
                                                                  child: Text(
                                                                    "Absent",
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),

                                                                SizedBox(
                                                                  width: 80,
                                                                  child: Text(
                                                                    "OT Hours",
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),

                                                                SizedBox(
                                                                  width: 110,
                                                                  child: Text(
                                                                    "OT Pay",
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),

                                                                SizedBox(
                                                                  width: 110,
                                                                  child: Text(
                                                                    "Daily Salary",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: 125,
                                  child: Text(
                                    "Total",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Divider(),

                          // PAYROLL ROWS
                          ...payrollData.asMap().entries.map((entry) {
                            final index = entry.key;
                            final worker = entry.value;

                            final presentDays =
                                (worker['present_days'] ?? 0) as num;

                            final recoveryDays =
                                (worker['recovery_days'] ?? 0) as num;

                            final halfDays = (worker['half_days'] ?? 0) as num;

                            final absentDays =
                                                            (worker['absent_days'] ?? 0) as num;

                                                        final overtimeHours = ((worker['overtime_hours'] ?? 0) as num);
                                                        final overtimePay = ((worker['overtime_pay'] ?? 0) as num);

                                                        final dailySalary =
                                                            (worker['daily_salary'] ?? 0) as num;

                                                        final totalSalary =
                                                            (presentDays * dailySalary) +
                                                            (recoveryDays * dailySalary) +
                                                            (halfDays * dailySalary * 0.5) +
                                                            overtimePay;

                                                        return Card(
                                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 12,
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                SizedBox(
                                                                  width: 45,
                                                                  child: Text("${index + 1}"),
                                                                ),

                                                                SizedBox(
                                                                  width: 90,
                                                                  child: Text(
                                                                    worker['reference']?.toString() ?? '',
                                                                    style: const TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),

                                                                SizedBox(
                                                                  width: 220,
                                                                  child: Text(
                                                                    worker['full_name']?.toString() ?? '',
                                                                  ),
                                                                ),

                                                                SizedBox(
                                                                  width: 80,
                                                                  child: Text(presentDays.toString()),
                                                                ),

                                                                SizedBox(
                                                                  width: 80,
                                                                  child: Text(recoveryDays.toString()),
                                                                ),

                                                                SizedBox(
                                                                  width: 80,
                                                                  child: Text(halfDays.toString()),
                                                                ),

                                                                SizedBox(
                                                                  width: 80,
                                                                  child: Text(absentDays.toString()),
                                                                ),

                                                                SizedBox(
                                                                  width: 80,
                                                                  child: Text(overtimeHours.toStringAsFixed(1)),
                                                                ),

                                                                SizedBox(
                                                                  width: 110,
                                                                  child: Text(
                                                                    "${overtimePay.toStringAsFixed(2)} $currency",
                                                                  ),
                                                                ),

                                                                SizedBox(
                                                                  width: 110,
                                                                  child: Text(
                                                                    "${dailySalary.toStringAsFixed(2)} $currency",
                                                                  ),
                                                                ),

                                                                SizedBox(
                                                                  width: 125,
                                                                  child: Text(
                                                                    "${totalSalary.toStringAsFixed(2)} $currency",
                                                                    style: const TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                          }),
                          const SizedBox(height: 10),

                          // GRAND TOTAL
                          // GRAND TOTAL
                          Builder(
                            builder: (context) {
                              double grandTotal = 0;
                              double grandPaid = 0;
                              double grandRemaining = 0;

                              for (final worker in payrollData) {
                                                              final dailySalary =
                                                                  ((worker['daily_salary'] ?? 0) as num)
                                                                      .toDouble();

                                                              final present =
                                                                  ((worker['present_days'] ?? 0) as num)
                                                                      .toDouble();

                                                              final recovery =
                                                                  ((worker['recovery_days'] ?? 0) as num)
                                                                      .toDouble();

                                                              final halfDay =
                                                                  ((worker['half_days'] ?? 0) as num)
                                                                      .toDouble();

                                                              final overtimePay =
                                                                  ((worker['overtime_pay'] ?? 0) as num)
                                                                      .toDouble();

                                                              final totalSalary =
                                                                  (present * dailySalary) +
                                                                  (recovery * dailySalary) +
                                                                  (halfDay * dailySalary * 0.5) +
                                                                  overtimePay;

                                                              final paid =
                                                                  paidAmounts[worker['id'] as int] ?? 0;

                                                              final remaining = totalSalary - paid;

                                                              grandTotal += totalSalary;
                                                              grandPaid += paid;
                                                              grandRemaining += remaining;
                                                            }

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              "GRAND TOTAL",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          Text(
                                            "${grandTotal.toStringAsFixed(2)} $currency",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text("TOTAL PAID"),
                                          ),

                                          Text(
                                            "${grandPaid.toStringAsFixed(2)} $currency",
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              "REMAINING",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          Text(
                                            "${grandRemaining.toStringAsFixed(2)} $currency",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
          );
        },
      ),
    );
  }
}

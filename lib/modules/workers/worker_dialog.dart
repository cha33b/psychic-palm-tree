import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/services/database_service.dart';
import 'package:worker_salary_manager/models/company.dart';
import 'package:worker_salary_manager/models/worker.dart';
import 'package:worker_salary_manager/models/project.dart';

Future<bool?> showWorkerDialog(BuildContext context, {Worker? worker}) async {
  final nameController = TextEditingController(text: worker?.fullName ?? '');
  final phoneController = TextEditingController(text: worker?.phone ?? '');
  final salaryController = TextEditingController(
    text: worker == null ? '' : worker.dailySalary.toString(),
  );
  final positionController = TextEditingController(
    text: worker?.position ?? '',
  );

  // Load companies first
  final companiesResult = await DatabaseService.instance.getCompanies(context);
  if (!context.mounted) return null;
  if (companiesResult == null) return null;
  final companies = companiesResult.map((e) => Company.fromMap(e)).toList();

  // Load initial projects for the selected company
  List<Project> initialProjects = [];
  int? initialSelectedCompanyId = worker?.companyId;
  if (initialSelectedCompanyId != null) {
    final projectData = await DatabaseService.instance.getProjectsByCompany(
      context,
      initialSelectedCompanyId,
    );
    if (projectData != null) {
      initialProjects = projectData.map((e) => Project.fromMap(e)).toList();
    }
  }

  // Use a stateful wrapper to hold dialog-local state
  int? selectedCompanyId = initialSelectedCompanyId;
  int? selectedProjectId = worker?.projectId;
  List<Project> filteredProjects = initialProjects;

  return await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          // Build display list: "No Project" + projects for selected company
          final List<Project> displayProjects = [
            Project(
              id: null,
              reference: '',
              companyId: 0,
              name: 'No Project',
              location: '',
              startDate: '',
              endDate: '',
              status: '',
            ),
            ...filteredProjects,
          ];

          return ContentDialog(
            title: Text(worker == null ? "Add Worker" : "Edit Worker"),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Company selection
                  ComboBox<int>(
                    value: selectedCompanyId,
                    placeholder: const Text("Select Company"),
                    items: companies
                        .map((company) => ComboBoxItem<int>(
                              value: company.id!,
                              child: Text(company.name),
                            ))
                        .toList(),
                    onChanged: (value) async {
                      setState(() {
                        selectedCompanyId = value;
                        selectedProjectId = null;
                      });
                      if (value != null) {
                        final projectData =
                            await DatabaseService.instance.getProjectsByCompany(
                          context,
                          value,
                        );
                        if (projectData != null) {
                          setState(() {
                            filteredProjects = projectData
                                .map((e) => Project.fromMap(e))
                                .toList();
                          });
                        } else {
                          setState(() {
                            filteredProjects = [];
                          });
                        }
                      } else {
                        setState(() {
                          filteredProjects = [];
                        });
                      }
                    },
                  ),

                  // Project selection - shows reference + name, includes "No Project"
                  ComboBox<int>(
                    value: selectedProjectId,
                    placeholder: const Text("Select Project"),
                    items: displayProjects.map((project) {
                      final label = project.id == null
                          ? 'No Project'
                          : '${project.reference} - ${project.name}';
                      return ComboBoxItem<int>(
                        value: project.id,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProjectId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),
                  TextBox(
                    controller: nameController,
                    placeholder: 'Full Name',
                  ),
                  const SizedBox(height: 10),
                  TextBox(
                    controller: phoneController,
                    placeholder: 'Phone',
                  ),
                  const SizedBox(height: 10),
                  TextBox(
                    controller: salaryController,
                    placeholder: 'Daily Salary',
                  ),
                  const SizedBox(height: 10),
                  TextBox(
                    controller: positionController,
                    placeholder: 'Position',
                  ),
                ],
              ),
            ),
            actions: [
              Button(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
              ),
              FilledButton(
                child: const Text('Save'),
                onPressed: () async {
                  if (selectedCompanyId == null) {
                    displayInfoBar(
                      dialogContext,
                      builder: (context, close) => const InfoBar(
                        title: Text("Error"),
                        content: Text("Please select a company."),
                        severity: InfoBarSeverity.warning,
                      ),
                    );
                    return;
                  }

                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    displayInfoBar(
                      dialogContext,
                      builder: (context, close) => const InfoBar(
                        title: Text("Error"),
                        content: Text("Worker name is required."),
                        severity: InfoBarSeverity.warning,
                      ),
                    );
                    return;
                  }

                  final salary =
                      double.tryParse(salaryController.text.trim()) ?? 0;
                  if (salary <= 0) {
                    displayInfoBar(
                      dialogContext,
                      builder: (context, close) => const InfoBar(
                        title: Text("Error"),
                        content: Text(
                            "Daily salary must be greater than zero."),
                        severity: InfoBarSeverity.warning,
                      ),
                    );
                    return;
                  }

                  final ref = worker?.reference ??
                      await DatabaseService.instance.generateReference(
                            context,
                            'workers',
                            'WRK',
                          ) ??
                      'WRK001';
                  final newWorker = Worker(
                    id: worker?.id,
                    reference: ref,
                    companyId: selectedCompanyId!,
                    projectId: selectedProjectId,
                    fullName: name,
                    phone: phoneController.text.trim(),
                    dailySalary: salary,
                    position: positionController.text.trim(),
                    hireDate: worker?.hireDate ??
                        DateTime.now().toIso8601String(),
                  );

                  if (worker == null) {
                    await DatabaseService.instance.insertWorker(
                      context,
                      newWorker.toMap(),
                    );
                  } else {
                    await DatabaseService.instance.updateWorker(
                      context,
                      newWorker.toMap(),
                    );
                  }

                  debugPrint("Worker saved successfully");

                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}
import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/services/database_service.dart';
import 'package:worker_salary_manager/models/company.dart';
import 'package:worker_salary_manager/models/project.dart';

Future<bool?> showProjectDialog(
  BuildContext context, {
  Project? project,
}) async {
  final nameController = TextEditingController(text: project?.name ?? '');
  final locationController = TextEditingController(
    text: project?.location ?? '',
  );

  final companiesResult = await DatabaseService.instance.getCompanies(context);

  if (!context.mounted) return false;

  if (companiesResult == null) {
    return false;
  }

  final companies = companiesResult.map((e) => Company.fromMap(e)).toList();

  int? selectedCompanyId = project?.companyId;

  return await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: Text(project == null ? "Add Project" : "Edit Project"),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ComboBox<int>(
                    value: selectedCompanyId,
                    placeholder: const Text("Select Company"),
                    items: companies.map((company) {
                      return ComboBoxItem<int>(
                        value: company.id!,
                        child: Text(company.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCompanyId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  TextBox(
                    controller: nameController,
                    placeholder: "Project Name",
                  ),

                  const SizedBox(height: 12),

                  TextBox(
                    controller: locationController,
                    placeholder: "Location",
                  ),
                ],
              ),
            ),
            actions: [
              Button(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
              ),
              FilledButton(
                child: const Text("Save"),
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
                        content: Text("Project name is required."),
                        severity: InfoBarSeverity.warning,
                      ),
                    );
                    return;
                  }
                  final ref = project?.reference ??
                      await DatabaseService.instance.generateReference(
                            dialogContext,
                            'projects',
                            'PRJ',
                          ) ??
                      'PRJ001';
                  final newProject = Project(
                    id: project?.id,
                    reference: ref,
                    companyId: selectedCompanyId!,
                    name: nameController.text.trim(),
                    location: locationController.text.trim(),
                    startDate: project?.startDate ?? "",
                    endDate: project?.endDate ?? "",
                    status: project?.status ?? "Active",
                  );

                  if (project == null) {
                    await DatabaseService.instance.insertProject(
                      dialogContext,
                      newProject.toMap(),
                    );
                  } else {
                    await DatabaseService.instance.updateProject(
                      dialogContext,
                      newProject.toMap(),
                    );
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          );
        },
      );
    },
  );
}
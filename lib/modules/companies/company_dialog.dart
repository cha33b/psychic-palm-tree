import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/services/database_service.dart';
import 'package:worker_salary_manager/models/company.dart';

Future<void> showCompanyDialog(
  BuildContext context, {
  Company? company,
  required VoidCallback onSaved,
}) async {
  final nameController = TextEditingController(text: company?.name ?? '');
  final addressController = TextEditingController(text: company?.address ?? '');
  final phoneController = TextEditingController(text: company?.phone ?? '');

  await showDialog(
    context: context,
    builder: (context) {
      return ContentDialog(
        title: Text(company == null ? 'Add Company' : 'Edit Company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextBox(controller: nameController, placeholder: 'Company Name'),
            const SizedBox(height: 10),
            TextBox(controller: addressController, placeholder: 'Address'),
            const SizedBox(height: 10),
            TextBox(controller: phoneController, placeholder: 'Phone Number'),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          FilledButton(
            child: const Text('Save'),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                displayInfoBar(
                  context,
                  builder: (context, close) => const InfoBar(
                    title: Text('Validation Error'),
                    content: Text('Company name is required.'),
                    severity: InfoBarSeverity.warning,
                  ),
                );
                return;
              }

              final reference = company?.reference ??
                  await DatabaseService.instance.generateReference(
                        context,
                        "companies",
                        "CMP",
                      ) ??
                  'CMP001';
              final data = Company(
                id: company?.id,
                reference: reference,
                name: name,
                address: addressController.text.trim(),
                phone: phoneController.text.trim(),
              );

              if (company == null) {
                await DatabaseService.instance.insertCompany(context, data.toMap());
              } else {
                await DatabaseService.instance.updateCompany(context, data.toMap());
              }

              onSaved();

              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}
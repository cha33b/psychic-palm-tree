import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/database/database_helper.dart';
import 'package:worker_salary_manager/models/company.dart';
import 'package:worker_salary_manager/modules/companies/company_dialog.dart';

const Color _grey40 = Color(0xFFB4B4B4);

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  List<Company> companies = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadCompanies();
  }

  Future<void> loadCompanies() async {
    final data = await DatabaseHelper.instance.getCompanies();

    setState(() {
      companies = data.map((e) => Company.fromMap(e)).toList();
    });
  }

  Future<void> deleteCompany(int id) async {
    await DatabaseHelper.instance.deleteCompany(id);

    await loadCompanies();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Companies'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              child: const Text('Add Company'),
              onPressed: () async {
                await showCompanyDialog(context, onSaved: loadCompanies);
              },
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: _grey40)),
                                    ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextBox(
                    placeholder: 'Search companies...',
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                    prefix: const Icon(FluentIcons.search),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: companies.isEmpty
                ? const Center(
                    child: Text('No companies yet.', style: TextStyle(fontSize: 18)),
                  )
                : Column(
                    children: [
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
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            SizedBox(
                              width: 80,
                              child: Text(
                                "Ref",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(
                                "Company",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child: Text(
                                "Phone",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(
                                "Address",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            SizedBox(width: 40),
                            SizedBox(width: 40),
                          ],
                        ),
                      ),

                      const Divider(),

                      Expanded(
                        child: ListView.builder(
                          itemCount: companies.length,
                          itemBuilder: (context, index) {
                            final company = companies[index];

                            // Apply search filter
                            final name = company.name.toLowerCase();
                            final reference = company.reference.toLowerCase();
                            final phone = company.phone.toLowerCase();
                            final address = company.address.toLowerCase();

                            final matchesSearch = _searchQuery.isEmpty ||
                                name.contains(_searchQuery) ||
                                reference.contains(_searchQuery) ||
                                phone.contains(_searchQuery) ||
                                address.contains(_searchQuery);

                            if (!matchesSearch) {
                              return const SizedBox.shrink();
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(width: 45, child: Text("${index + 1}")),

                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        company.reference,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    Expanded(flex: 3, child: Text(company.name)),

                                    Expanded(flex: 2, child: Text(company.phone)),

                                    Expanded(flex: 3, child: Text(company.address)),

                                    IconButton(
                                      icon: const Icon(FluentIcons.edit),
                                      onPressed: () async {
                                        await showCompanyDialog(
                                          context,
                                          company: company,
                                          onSaved: loadCompanies,
                                        );
                                      },
                                    ),

                                    IconButton(
                                      icon: const Icon(FluentIcons.delete),
                                      onPressed: () async {
                                        final result = await showDialog<bool>(
                                          context: context,
                                          builder: (context) {
                                            return ContentDialog(
                                              title: const Text('Delete Company'),
                                              content: Text(
                                                'Delete "${company.name}"?',
                                              ),
                                              actions: [
                                                Button(
                                                  child: const Text('Cancel'),
                                                  onPressed: () {
                                                    Navigator.pop(context, false);
                                                  },
                                                ),
                                                FilledButton(
                                                  child: const Text('Delete'),
                                                  onPressed: () {
                                                    Navigator.pop(context, true);
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (result == true && company.id != null) {
                                          await deleteCompany(company.id!);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
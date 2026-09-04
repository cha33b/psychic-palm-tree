import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/modules/workers/worker_dialog.dart';
import 'package:worker_salary_manager/database/database_helper.dart';
import 'package:worker_salary_manager/models/worker.dart';

const Color _grey40 = Color(0xFFB4B4B4);

class WorkersPage extends StatefulWidget {
  const WorkersPage({super.key});

  @override
  State<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends State<WorkersPage> {
  String _searchQuery = '';
  String _selectedCompany = 'All';
  String _selectedProject = 'All';
  List<String> _companies = ['All'];
  List<String> _projects = ['All'];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    final companiesData = await DatabaseHelper.instance.getCompanies();
    final projectsData = await DatabaseHelper.instance.getProjects();

    if (!mounted) return;

    setState(() {
      _companies = ['All'] + companiesData.map((c) => c['name'] as String).toList();
      _projects = ['All'] + projectsData.map((p) => p['name'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Workers'),
        commandBar: FilledButton(
          child: const Text('Add Worker'),
          onPressed: () async {
            final result = await showWorkerDialog(context);

            if (result == true && mounted) {
              setState(() {});
              await _loadFilterOptions();
            }
          },
        ),
      ),
      content: Column(
        children: [
          // Search and Filter Bar
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
                    placeholder: 'Search workers...',
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                    prefix: const Icon(FluentIcons.search),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ComboBox<String>(
                    value: _selectedCompany,
                    items: _companies
                        .map((c) => ComboBoxItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCompany = value);
                      }
                    },
                    placeholder: const Text('Filter by Company'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ComboBox<String>(
                    value: _selectedProject,
                    items: _projects
                        .map((p) => ComboBoxItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedProject = value);
                      }
                    },
                    placeholder: const Text('Filter by Project'),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getWorkersWithDetails(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: ProgressRing());
                }

                final workers = snapshot.data!;

                // Apply filters
                var filteredWorkers = workers.where((worker) {
                  final name = (worker['full_name'] ?? '').toLowerCase();
                  final reference = (worker['reference'] ?? '').toLowerCase();
                  final company = (worker['company_name'] ?? '').toLowerCase();
                  final project = (worker['project_name'] ?? '').toLowerCase();
                  final phone = (worker['phone'] ?? '').toLowerCase();

                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      reference.contains(_searchQuery) ||
                      company.contains(_searchQuery) ||
                      project.contains(_searchQuery) ||
                      phone.contains(_searchQuery);

                  final matchesCompany = _selectedCompany == 'All' ||
                      worker['company_name'] == _selectedCompany;

                  final matchesProject = _selectedProject == 'All' ||
                      worker['project_name'] == _selectedProject;

                  return matchesSearch && matchesCompany && matchesProject;
                }).toList();

                if (filteredWorkers.isEmpty) {
                  return const Center(
                    child: Text("No workers found.", style: TextStyle(fontSize: 18)),
                  );
                }

                return ListView.builder(
                  itemCount: filteredWorkers.length,
                  itemBuilder: (context, index) {
                    final worker = filteredWorkers[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(width: 45, child: Text("${index + 1}")),

                            SizedBox(
                              width: 80,
                              child: Text(
                                worker['reference'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(
                                worker['full_name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(worker['company_name'] ?? ''),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(
                                worker['project_name'] ?? 'No Project',
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child: Text(worker['phone'] ?? ''),
                            ),

                            Expanded(
                              flex: 2,
                              child: Text("${worker['daily_salary']} DA"),
                            ),

                            Expanded(
                              flex: 2,
                              child: Text(worker['position'] ?? ''),
                            ),

                            IconButton(
                              icon: const Icon(FluentIcons.edit),
                              onPressed: () async {
                                final workerModel = Worker(
                                  id: worker['id'],
                                  reference: worker['reference'],
                                  companyId: worker['company_id'],
                                  projectId: worker['project_id'],
                                  fullName: worker['full_name'],
                                  phone: worker['phone'] ?? '',
                                  dailySalary: (worker['daily_salary'] as num)
                                      .toDouble(),
                                  position: worker['position'] ?? '',
                                  hireDate: worker['hire_date'] ?? '',
                                );

                                final result = await showWorkerDialog(
                                  context,
                                  worker: workerModel,
                                );

                                if (result == true && mounted) {
                                  setState(() {});
                                }
                              },
                            ),

                            IconButton(
                              icon: const Icon(FluentIcons.delete),
                              onPressed: () async {
                                final result = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return ContentDialog(
                                      title: const Text("Delete Worker"),
                                      content: Text(
                                        "Delete ${worker['full_name']}?",
                                      ),
                                      actions: [
                                        Button(
                                          child: const Text("Cancel"),
                                          onPressed: () {
                                            Navigator.pop(dialogContext, false);
                                          },
                                        ),
                                        FilledButton(
                                          child: const Text("Delete"),
                                          onPressed: () {
                                            Navigator.pop(dialogContext, true);
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (result == true) {
                                  await DatabaseHelper.instance.deleteWorker(
                                    worker['id'],
                                  );

                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
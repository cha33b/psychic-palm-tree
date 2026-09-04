import 'package:fluent_ui/fluent_ui.dart';
import 'package:worker_salary_manager/modules/projects/project_dialog.dart';
import 'package:worker_salary_manager/database/database_helper.dart';
import 'package:worker_salary_manager/models/project.dart';

const Color _grey40 = Color(0xFFB4B4B4);

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Projects'),
        commandBar: FilledButton(
          child: const Text('Add Project'),
          onPressed: () async {
            final result = await showProjectDialog(context);

            if (result == true) {
              setState(() {});
            }
          },
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
                    placeholder: 'Search projects...',
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getProjectsWithCompany(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: ProgressRing());
                }

                final projects = snapshot.data!;

                // Apply search filter
                var filteredProjects = projects.where((project) {
                  final name = (project['name'] ?? '').toLowerCase();
                  final reference = (project['reference'] ?? '').toLowerCase();
                  final company = (project['company_name'] ?? '').toLowerCase();
                  final location = (project['location'] ?? '').toLowerCase();
                  final status = (project['status'] ?? '').toLowerCase();

                  return _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      reference.contains(_searchQuery) ||
                      company.contains(_searchQuery) ||
                      location.contains(_searchQuery) ||
                      status.contains(_searchQuery);
                }).toList();

                if (filteredProjects.isEmpty) {
                  return const Center(
                    child: Text("No projects found.", style: TextStyle(fontSize: 18)),
                  );
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
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
                              "Project",
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
                            flex: 4,
                            child: Text(
                              "Location",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                          Expanded(
                            flex: 2,
                            child: Text(
                              "Status",
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
                        itemCount: filteredProjects.length,
                        itemBuilder: (context, index) {
                          final project = filteredProjects[index];

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
                                      project['reference'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  Expanded(flex: 3, child: Text(project['name'])),

                                  Expanded(
                                    flex: 3,
                                    child: Text(project['company_name'] ?? ''),
                                  ),

                                  Expanded(
                                    flex: 4,
                                    child: Text(project['location'] ?? ''),
                                  ),

                                  Expanded(flex: 2, child: Text(project['status'])),

                                  IconButton(
                                    icon: const Icon(FluentIcons.edit),
                                    onPressed: () async {
                                      final projectModel = Project(
                                        id: project['id'],
                                        reference: project['reference'],
                                        companyId: project['company_id'],
                                        name: project['name'],
                                        location: project['location'] ?? '',
                                        startDate: project['start_date'] ?? '',
                                        endDate: project['end_date'] ?? '',
                                        status: project['status'] ?? 'Active',
                                      );

                                      final result = await showProjectDialog(
                                        context,
                                        project: projectModel,
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
                                            title: const Text("Delete Project"),
                                            content: Text(
                                              'Delete "${project['name']}"?',
                                            ),
                                            actions: [
                                              Button(
                                                child: const Text("Cancel"),
                                                onPressed: () {
                                                  Navigator.pop(
                                                    dialogContext,
                                                    false,
                                                  );
                                                },
                                              ),
                                              FilledButton(
                                                child: const Text("Delete"),
                                                onPressed: () {
                                                  Navigator.pop(
                                                    dialogContext,
                                                    true,
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (result == true) {
                                        await DatabaseHelper.instance.deleteProject(
                                          project['id'],
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
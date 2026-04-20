import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../models/pubspec_model.dart';
import '../providers/project_provider.dart';

class PubspecManagerScreen extends ConsumerStatefulWidget {
  final int projectIndex;

  const PubspecManagerScreen({
    super.key,
    required this.projectIndex,
  });

  @override
  ConsumerState<PubspecManagerScreen> createState() => _PubspecManagerScreenState();
}

class _PubspecManagerScreenState extends ConsumerState<PubspecManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showDevDependencies = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider)[widget.projectIndex];
    final pubspec = project.pubspec ?? PubspecConfig.defaultConfig();

    final allDeps = pubspec.allDependencies;
    final filteredDeps = _searchQuery.isEmpty
        ? allDeps
        : allDeps.where((d) =>
            d.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final popularFiltered = _searchQuery.isEmpty
        ? popularPackages
        : popularPackages.where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pubspec Manager',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              project.appName,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddPackageDialog(context, project, pubspec),
            icon: const Icon(Icons.add),
            tooltip: 'Add Package',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left sidebar - Popular packages
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Popular Packages',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: popularFiltered.length,
                    itemBuilder: (context, index) {
                      final package = popularFiltered[index];
                      final isAdded = allDeps.any((d) => d.name == package.name);

                      return _buildPackageCard(
                        package: package,
                        isAdded: isAdded,
                        onTap: isAdded
                            ? null
                            : () => _addPackage(project, pubspec, package),
                        onAdd: () => _addPackage(project, pubspec, package),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Right side - Current dependencies
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with search
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search packages...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Toggle for dev dependencies
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Dependencies'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Dev'),
                          ),
                        ],
                        selected: {_showDevDependencies},
                        onSelectionChanged: (v) {
                          setState(() => _showDevDependencies = v.first);
                        },
                      ),
                    ],
                  ),
                ),
                // Stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _buildStatChip(
                        '${pubspec.dependencies.length}',
                        'dependencies',
                        Colors.blue.shade100,
                        Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        '${pubspec.devDependencies.length}',
                        'dev dependencies',
                        Colors.orange.shade100,
                        Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        pubspec.sdkVersion,
                        'SDK',
                        Colors.green.shade100,
                        Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
                // Dependencies list
                Expanded(
                  child: filteredDeps.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredDeps.length,
                          itemBuilder: (context, index) {
                            final dep = filteredDeps[index];
                            if (dep.isDevDependency != _showDevDependencies) {
                              return const SizedBox.shrink();
                            }
                            return _buildDependencyCard(project, pubspec, dep);
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

  Widget _buildPackageCard({
    required PubspecDependency package,
    required bool isAdded,
    VoidCallback? onTap,
    required VoidCallback onAdd,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAdded ? Colors.green.shade300 : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isAdded ? Colors.green.shade700 : const Color(0xFF1E293B),
                      ),
                    ),
                    if (package.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        package.description!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      package.version,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ).copyWith(fontFamily: 'Consolas'),
                    ),
                  ],
                ),
              ),
              if (isAdded)
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 20)
              else
                IconButton(
                  onPressed: onAdd,
                  icon: Icon(Icons.add_circle, color: Colors.blue.shade400),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDependencyCard(
    ProjectData project,
    PubspecConfig pubspec,
    PubspecDependency dep,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dep.isDevDependency
                    ? Colors.orange.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                dep.isDevDependency ? Icons.construction : Icons.layers,
                size: 18,
                color: dep.isDevDependency
                    ? Colors.orange.shade400
                    : Colors.blue.shade400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dep.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dep.version,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ).copyWith(fontFamily: 'Consolas'),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _editPackage(project, pubspec, dep),
              icon: Icon(Icons.edit, size: 18, color: Colors.grey.shade600),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => _removePackage(project, pubspec, dep),
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
    String value,
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No ${_showDevDependencies ? "dev dependencies" : "dependencies"}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add packages from the left panel',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  void _addPackage(
    ProjectData project,
    PubspecConfig pubspec,
    PubspecDependency package, {
    bool isDev = false,
  }) {
    final newDep = package.copyWith(isDevDependency: isDev);
    final newPubspec = isDev
        ? pubspec.copyWith(
            devDependencies: [...pubspec.devDependencies, newDep],
          )
        : pubspec.copyWith(
            dependencies: [...pubspec.dependencies, newDep],
          );

    _updatePubspec(project, newPubspec);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${package.name}'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => _removePackage(project, pubspec, newDep),
        ),
      ),
    );
  }

  void _removePackage(ProjectData project, PubspecConfig pubspec, PubspecDependency dep) {
    final newPubspec = dep.isDevDependency
        ? pubspec.copyWith(
            devDependencies:
                pubspec.devDependencies.where((d) => d.name != dep.name).toList(),
          )
        : pubspec.copyWith(
            dependencies:
                pubspec.dependencies.where((d) => d.name != dep.name).toList(),
          );

    _updatePubspec(project, newPubspec);
  }

  void _updatePubspec(ProjectData project, PubspecConfig newPubspec) {
    final updatedProject = project.copyWith(pubspec: newPubspec);
    ref.read(projectProvider.notifier).updateProject(
          widget.projectIndex,
          updatedProject,
        );
  }

  Future<void> _showAddPackageDialog(
    BuildContext context,
    ProjectData project,
    PubspecConfig pubspec,
  ) async {
    final nameController = TextEditingController();
    final versionController = TextEditingController(text: '^1.0.0');
    bool isDev = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Package'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Package Name',
                    hintText: 'http',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: versionController,
                  decoration: const InputDecoration(
                    labelText: 'Version',
                    hintText: '^1.0.0',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Dev Dependency'),
                  value: isDev,
                  onChanged: (v) => setState(() => isDev = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final version = versionController.text.trim();
                if (name.isNotEmpty && version.isNotEmpty) {
                  _addPackage(
                    project,
                    pubspec,
                    PubspecDependency(
                      name: name,
                      version: version,
                      isDevDependency: isDev,
                    ),
                    isDev: isDev,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    versionController.dispose();
  }

  Future<void> _editPackage(
    ProjectData projectData,
    PubspecConfig pubspec,
    PubspecDependency dep,
  ) async {
    final versionController = TextEditingController(text: dep.version);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${dep.name}'),
        content: TextField(
          controller: versionController,
          decoration: const InputDecoration(
            labelText: 'Version',
            hintText: '^1.0.0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newVersion = versionController.text.trim();
              if (newVersion.isNotEmpty) {
                final updatedDep = dep.copyWith(version: newVersion);
                final newPubspec = dep.isDevDependency
                    ? pubspec.copyWith(
                        devDependencies: pubspec.devDependencies
                            .map((d) => d.name == dep.name ? updatedDep : d)
                            .toList(),
                      )
                    : pubspec.copyWith(
                        dependencies: pubspec.dependencies
                            .map((d) => d.name == dep.name ? updatedDep : d)
                            .toList(),
                      );
                _updatePubspec(projectData, newPubspec);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    versionController.dispose();
  }
}

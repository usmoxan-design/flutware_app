import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../providers/project_provider.dart';
import '../dialogs/new_project_dialog.dart';
import 'editor_screen.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectProvider);
    final filtered = _query.isEmpty
        ? projects
        : projects.where((p) {
            final name = p.appName.toLowerCase();
            final pkg = p.packageName.toLowerCase();
            return name.contains(_query) || pkg.contains(_query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projectlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yangi project',
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Project qidirish...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
          ),
          Expanded(
            child: projects.isEmpty
                ? _buildEmptyState(context)
                : filtered.isEmpty
                    ? _buildEmptySearch(context)
                    : _buildProjectList(context, filtered),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        label: const Text('Yangi Project'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProjectList(BuildContext context, List<ProjectData> projects) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final project = projects[index];
        final accent = _parseColor(project.colorPrimary);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            onTap: () => _openProject(context, index),
            onLongPress: () =>
                _showDeleteDialog(context, index, project.appName),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: accent.withOpacity(0.15),
              child: Text(
                _initial(project.appName),
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              project.appName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.packageName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${project.pages.length} ta sahifa • v${project.versionName}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade300,
              onPressed: () =>
                  _showDeleteDialog(context, index, project.appName),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open, size: 42),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hozircha projectlar yo\'q',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Yangi project yarating va bloklar bilan ishlashni boshlang.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Yangi Project'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearch(BuildContext context) {
    return const Center(
      child: Text(
        'Hech narsa topilmadi',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  void _openProject(BuildContext context, int index) {
    ref.read(currentProjectIndexProvider.notifier).state = index;
    ref.read(currentPageIndexProvider.notifier).state = 0;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditorScreen()),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NewProjectDialog(),
    );
  }

  void _showDeleteDialog(BuildContext context, int index, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projectni o\'chirish'),
        content: Text('"$name" projectini o\'chirishni xohlaysizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yo\'q'),
          ),
          TextButton(
            onPressed: () {
              ref.read(projectProvider.notifier).deleteProject(index);
              Navigator.pop(context);
            },
            child: const Text('Ha', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _initial(String name) {
    if (name.isEmpty) return '?';
    return name.trim().substring(0, 1).toUpperCase();
  }

  Color _parseColor(String value) {
    final hex = value.toLowerCase().replaceAll('0x', '');
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return const Color(0xFF4A90E2);
    return Color(parsed);
  }
}

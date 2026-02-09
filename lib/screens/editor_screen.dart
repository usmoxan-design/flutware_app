import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_models.dart';
import '../providers/project_provider.dart';
import 'tabs/ui_tab.dart';
import 'tabs/logic_tab.dart';
import 'tabs/preview_tab.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
    final page = ref.watch(currentPageProvider);
    final projectIndex = ref.watch(currentProjectIndexProvider);
    final pageIndex = ref.watch(currentPageIndexProvider);

    if (project == null || page == null) {
      return const Scaffold(body: Center(child: Text('Yuklanmoqda...')));
    }

    final showEventTab = page.type == 'StatefulWidget';
    final tabs = <Tab>[
      const Tab(text: 'View'),
      if (showEventTab) const Tab(text: 'Event'),
      const Tab(text: 'Build APK'),
    ];
    final tabViews = <Widget>[
      const UiTab(),
      if (showEventTab) const LogicTab(),
      const PreviewTab(),
    ];

    return DefaultTabController(
      key: ValueKey('${page.id}_${tabs.length}'),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.appName, style: const TextStyle(fontSize: 18)),
              Text(
                'v${project.versionName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          bottom: TabBar(tabs: tabs),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Undo hozircha mavjud emas')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Redo hozircha mavjud emas')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save',
              onPressed: () {
                if (projectIndex != null) {
                  ref
                      .read(projectProvider.notifier)
                      .updateProject(projectIndex, project);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loyiha saqlandi')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Sozlamalar',
              onPressed: () {
                _showProjectSettings(context, ref, project, projectIndex);
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'cache':
                    _clearBuildCache(context);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'cache',
                  child: Text('Build cache tozalash'),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(children: tabViews),
        bottomNavigationBar: _buildPageDock(
          context,
          ref,
          project,
          projectIndex,
          pageIndex,
        ),
      ),
    );
  }

  Widget _buildPageDock(
    BuildContext context,
    WidgetRef ref,
    ProjectData project,
    int? projectIndex,
    int? pageIndex,
  ) {
    if (projectIndex == null || pageIndex == null || pageIndex < 0) {
      return const SizedBox.shrink();
    }

    final currentPage = project.pages[pageIndex];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          children: [
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _showWidgetTreePicker(context, ref, project),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Widgets'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showPagePicker(context, ref, project, pageIndex),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.crop_square, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pageFileName(currentPage.name),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showQuickCreateView(context, ref, project, projectIndex),
                icon: const Icon(Icons.add),
                label: const Text('Create view'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPagePicker(
    BuildContext context,
    WidgetRef ref,
    ProjectData project,
    int currentIndex,
  ) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Pages',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < project.pages.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.crop_square_outlined, size: 18),
                title: Text(_pageFileName(project.pages[i].name)),
                subtitle: Text(
                  project.pages[i].type,
                  style: const TextStyle(fontSize: 11),
                ),
                selected: i == currentIndex,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i == currentIndex)
                      const Icon(Icons.check, color: Colors.blue),
                    if (i > 0) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () async {
                          final nextName = await _showRenamePageDialog(
                            context,
                            project.pages[i].name,
                          );
                          if (nextName == null || nextName.isEmpty) return;
                          final pages = [...project.pages];
                          pages[i] = pages[i].copyWith(name: nextName);
                          final pIdx = ref.read(currentProjectIndexProvider);
                          if (pIdx == null) return;
                          ref
                              .read(projectProvider.notifier)
                              .updateProject(
                                pIdx,
                                project.copyWith(pages: pages),
                              );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () {
                          final pages = [...project.pages]..removeAt(i);
                          final pIdx = ref.read(currentProjectIndexProvider);
                          if (pIdx == null) return;
                          ref
                              .read(projectProvider.notifier)
                              .updateProject(
                                pIdx,
                                project.copyWith(pages: pages),
                              );
                          final current =
                              ref.read(currentPageIndexProvider) ?? 0;
                          if (current >= pages.length) {
                            ref.read(currentPageIndexProvider.notifier).state =
                                pages.length - 1;
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ],
                ),
                onTap: () => Navigator.pop(context, i),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null && selected != currentIndex) {
      ref.read(currentPageIndexProvider.notifier).state = selected;
      ref.read(selectedWidgetIdProvider.notifier).state = null;
    }
  }

  Future<void> _showWidgetTreePicker(
    BuildContext context,
    WidgetRef ref,
    ProjectData project,
  ) async {
    final pageIndex = ref.read(currentPageIndexProvider);
    if (pageIndex == null || pageIndex >= project.pages.length) return;
    final page = project.pages[pageIndex];
    final nodes = _flattenWidgetTree(page.widgets);

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Widget tree',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (nodes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Widget yo\'q'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.only(
                        left: 12 + node.depth * 14,
                        right: 12,
                      ),
                      title: Text('${node.id} (${node.type})'),
                      onTap: () => Navigator.pop(context, node.id),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null) {
      if (!context.mounted) return;
      ref.read(selectedWidgetIdProvider.notifier).state = selected;
      final controller = DefaultTabController.of(context);
      controller.animateTo(0);
    }
  }

  Future<void> _showQuickCreateView(
    BuildContext context,
    WidgetRef ref,
    ProjectData project,
    int projectIndex,
  ) async {
    final controller = TextEditingController();
    String widgetType = 'StatefulWidget';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yangi sahifa qo\'shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'HomePage',
                  isDense: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: widgetType,
                items: const [
                  DropdownMenuItem(
                    value: 'StatelessWidget',
                    child: Text('StatelessWidget'),
                  ),
                  DropdownMenuItem(
                    value: 'StatefulWidget',
                    child: Text('StatefulWidget'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => widgetType = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'name': controller.text.trim(),
                'type': widgetType,
              }),
              child: const Text('Qo\'shish'),
            ),
          ],
        ),
      ),
    );

    final pageName = result?['name'];
    if (pageName == null || pageName.isEmpty) return;

    final page = PageData(
      id: 'page_${DateTime.now().millisecondsSinceEpoch}',
      name: pageName,
      type: result?['type'] ?? 'StatefulWidget',
    );
    final pages = [...project.pages, page];
    ref
        .read(projectProvider.notifier)
        .updateProject(projectIndex, project.copyWith(pages: pages));
    ref.read(currentPageIndexProvider.notifier).state = pages.length - 1;
  }

  Future<String?> _showRenamePageDialog(
    BuildContext context,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sahifa nomini o\'zgartirish'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'PageName',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  Future<void> _showProjectSettings(
    BuildContext context,
    WidgetRef ref,
    ProjectData project,
    int? projectIndex,
  ) async {
    if (projectIndex == null) return;

    final appName = TextEditingController(text: project.appName);
    final packageName = TextEditingController(text: project.packageName);
    final versionCode = TextEditingController(text: project.versionCode);
    final versionName = TextEditingController(text: project.versionName);
    final colorPrimary = TextEditingController(text: project.colorPrimary);
    final colorDark = TextEditingController(text: project.colorPrimaryDark);
    final colorAccent = TextEditingController(text: project.colorAccent);
    var useMaterial3 = project.useMaterial3;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              12,
              14,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Project sozlamalari',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField('App name', appName),
                  _buildTextField('Package name', packageName),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Version code', versionCode),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField('Version name', versionName),
                      ),
                    ],
                  ),
                  _buildTextField('colorPrimary', colorPrimary),
                  _buildTextField('colorPrimaryDark', colorDark),
                  _buildTextField('colorAccent', colorAccent),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('useMaterial3'),
                    value: useMaterial3,
                    onChanged: (value) =>
                        setDialogState(() => useMaterial3 = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Bekor'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref
                                .read(projectProvider.notifier)
                                .updateProject(
                                  projectIndex,
                                  project.copyWith(
                                    appName: appName.text.trim(),
                                    packageName: packageName.text.trim(),
                                    versionCode: versionCode.text.trim(),
                                    versionName: versionName.text.trim(),
                                    colorPrimary: colorPrimary.text.trim(),
                                    colorPrimaryDark: colorDark.text.trim(),
                                    colorAccent: colorAccent.text.trim(),
                                    useMaterial3: useMaterial3,
                                  ),
                                );
                            Navigator.pop(context);
                          },
                          child: const Text('Saqlash'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  List<_WidgetTreeNode> _flattenWidgetTree(List<WidgetData> widgets) {
    final out = <_WidgetTreeNode>[];

    void walk(List<WidgetData> nodes, int depth) {
      for (final node in nodes) {
        out.add(_WidgetTreeNode(id: node.id, type: node.type, depth: depth));
        final raw = node.properties['children'];
        if (raw is List) {
          final children = raw.whereType<Map>().map((entry) {
            return WidgetData.fromJson(Map<String, dynamic>.from(entry));
          }).toList();
          walk(children, depth + 1);
        }
      }
    }

    walk(widgets, 0);
    return out;
  }

  Future<void> _clearBuildCache(BuildContext context) async {
    try {
      final directory = await getTemporaryDirectory();
      if (directory.existsSync()) {
        final files = directory.listSync();
        int count = 0;
        for (var file in files) {
          if (file is File && file.path.endsWith('.apk')) {
            file.deleteSync();
            count++;
          }
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count ta eski build fayllari tozalandi.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tozalashda xatolik: $e')));
      }
    }
  }

  String _pageFileName(String pageName) {
    final name = _toSnake(pageName);
    return '${name.isEmpty ? 'page' : name}.dart';
  }

  String _toSnake(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
  }
}

class _WidgetTreeNode {
  final String id;
  final String type;
  final int depth;

  const _WidgetTreeNode({
    required this.id,
    required this.type,
    required this.depth,
  });
}

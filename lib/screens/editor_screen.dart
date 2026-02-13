import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../providers/project_provider.dart';
import 'tabs/ui_tab.dart';
import 'tabs/logic_tab.dart';
import 'tabs/preview_tab.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});
  static const int _createViewSentinel = -1;
  static const List<Color> _defaultColors = [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFF44336),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
    final page = ref.watch(currentPageProvider);
    final projectIndex = ref.watch(currentProjectIndexProvider);
    final pageIndex = ref.watch(currentPageIndexProvider);
    final canUndo = ref.watch(canUndoCurrentProjectProvider);
    final canRedo = ref.watch(canRedoCurrentProjectProvider);

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
    final baseTheme = Theme.of(context);
    final scopedTheme =
        ThemeData.from(
          colorScheme: baseTheme.colorScheme,
          useMaterial3: project.useMaterial3,
        ).copyWith(
          textTheme: baseTheme.textTheme,
          scaffoldBackgroundColor: baseTheme.scaffoldBackgroundColor,
          appBarTheme: baseTheme.appBarTheme,
          cardTheme: baseTheme.cardTheme,
          iconTheme: baseTheme.iconTheme,
          inputDecorationTheme: baseTheme.inputDecorationTheme,
          floatingActionButtonTheme: baseTheme.floatingActionButtonTheme,
          snackBarTheme: baseTheme.snackBarTheme,
        );

    return DefaultTabController(
      key: ValueKey('${page.id}_${tabs.length}'),
      length: tabs.length,
      child: Theme(
        data: scopedTheme,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
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
                onPressed: !canUndo || projectIndex == null
                    ? null
                    : () {
                        final done = ref
                            .read(projectProvider.notifier)
                            .undoProject(projectIndex);
                        if (!done) return;
                        ref.read(selectedWidgetIdProvider.notifier).state =
                            null;
                      },
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: 'Redo',
                onPressed: !canRedo || projectIndex == null
                    ? null
                    : () {
                        final done = ref
                            .read(projectProvider.notifier)
                            .redoProject(projectIndex);
                        if (!done) return;
                        ref.read(selectedWidgetIdProvider.notifier).state =
                            null;
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
            ],
          ),
          body: Stack(
            children: [
              // 1. PageDock (Pastki panel) - Har doim pastda turadi
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: baseTheme.scaffoldBackgroundColor, // Dock orqa foni
                  child: _buildPageDock(context, ref, project, pageIndex),
                ),
              ),
              // 2. TabBarView (Asosiy kontent)
              // Widget tanlanganda dock ustiga silliq yopilishi uchun AnimatedPadding ishlatamiz
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.only(
                  // 80 - dock va safe area uchun taxminiy balandlik
                  bottom: ref.watch(selectedWidgetIdProvider) == null ? 80 : 0,
                ),
                child: TabBarView(children: tabViews),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageDock(
    BuildContext context,
    WidgetRef ref,
    ProjectData project,
    int? pageIndex,
  ) {
    if (pageIndex == null || pageIndex < 0) {
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
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'Pages',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  itemCount: project.pages.length,
                  itemBuilder: (context, i) => ListTile(
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
                              final pIdx = ref.read(
                                currentProjectIndexProvider,
                              );
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
                              final pIdx = ref.read(
                                currentProjectIndexProvider,
                              );
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
                                ref
                                        .read(currentPageIndexProvider.notifier)
                                        .state =
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
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, _createViewSentinel),
                    icon: const Icon(Icons.add),
                    label: const Text('Create view'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == _createViewSentinel) {
      final pIdx = ref.read(currentProjectIndexProvider);
      if (pIdx == null) return;
      if (!context.mounted) return;
      await _showQuickCreateView(context, ref, project, pIdx);
      return;
    }

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
    var colorPrimary = _parseColor(
      project.colorPrimary,
      const Color(0xFF2196F3),
    );
    var colorDark = _parseColor(
      project.colorPrimaryDark,
      const Color(0xFF1976D2),
    );
    var colorAccent = _parseColor(project.colorAccent, const Color(0xFFFF4081));
    var useMaterial3 = project.useMaterial3;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => Scaffold(
            appBar: AppBar(title: const Text('Project sozlamalari')),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  children: [
                    _buildTextField('App name', appName),
                    _buildTextField('Package name', packageName),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Version code',
                            versionCode,
                            readOnly: true,
                            onTap: () async {
                              final current =
                                  int.tryParse(versionCode.text.trim()) ?? 1;
                              final picked = await _pickVersionCode(
                                context,
                                current,
                              );
                              if (picked == null) return;
                              setDialogState(
                                () => versionCode.text = picked.toString(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            'Version name',
                            versionName,
                            readOnly: true,
                            onTap: () async {
                              final picked = await _pickVersionName(
                                context,
                                versionName.text.trim(),
                              );
                              if (picked == null) return;
                              setDialogState(() => versionName.text = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    _buildColorField(
                      context: context,
                      label: 'colorPrimary',
                      color: colorPrimary,
                      onChanged: (color) {
                        setDialogState(() => colorPrimary = color);
                      },
                    ),
                    _buildColorField(
                      context: context,
                      label: 'colorPrimaryDark',
                      color: colorDark,
                      onChanged: (color) {
                        setDialogState(() => colorDark = color);
                      },
                    ),
                    _buildColorField(
                      context: context,
                      label: 'colorAccent',
                      color: colorAccent,
                      onChanged: (color) {
                        setDialogState(() => colorAccent = color);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('useMaterial3'),
                      subtitle: const Text(
                        'Faqat ushbu project preview/generatorga ta\'sir qiladi',
                        style: TextStyle(fontSize: 11),
                      ),
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
                                      colorPrimary: _colorToHex(colorPrimary),
                                      colorPrimaryDark: _colorToHex(colorDark),
                                      colorAccent: _colorToHex(colorAccent),
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
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<int?> _pickVersionCode(BuildContext context, int initial) {
    var selected = initial.clamp(1, 300);
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Version code'),
        content: SizedBox(
          height: 180,
          width: 140,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 34,
            controller: FixedExtentScrollController(initialItem: selected - 1),
            onSelectedItemChanged: (index) => selected = index + 1,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: 300,
              builder: (context, index) => Center(child: Text('${index + 1}')),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Tanlash'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickVersionName(BuildContext context, String current) {
    final parts = current.split('.');
    var major = int.tryParse(parts.firstOrNull ?? '1')?.clamp(0, 99) ?? 1;
    var minor =
        int.tryParse(parts.length > 1 ? parts[1] : '0')?.clamp(0, 99) ?? 0;

    Widget wheel({
      required int initialItem,
      required ValueChanged<int> onChanged,
    }) {
      return SizedBox(
        width: 80,
        height: 160,
        child: ListWheelScrollView.useDelegate(
          itemExtent: 34,
          controller: FixedExtentScrollController(initialItem: initialItem),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: 100,
            builder: (context, index) => Center(child: Text('$index')),
          ),
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Version name'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            wheel(initialItem: major, onChanged: (value) => major = value),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('.'),
            ),
            wheel(initialItem: minor, onChanged: (value) => minor = value),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, '$major.$minor'),
            child: const Text('Tanlash'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorField({
    required BuildContext context,
    required String label,
    required Color color,
    required ValueChanged<Color> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final picked = await _pickColor(context, color);
          if (picked == null) return;
          onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _colorToHex(color),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const Icon(Icons.palette_outlined, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color initial) {
    final presets = _defaultColors;
    var selected = initial;
    return showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: selected,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _colorToHex(selected),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in presets)
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => setSheetState(() => selected = color),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected.toARGB32() == color.toARGB32()
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildColorSlider(
                  label: 'R',
                  value: (selected.r * 255).roundToDouble(),
                  activeColor: Colors.red,
                  onChanged: (value) => setSheetState(
                    () => selected = selected.withRed(value.round()),
                  ),
                ),
                _buildColorSlider(
                  label: 'G',
                  value: (selected.g * 255).roundToDouble(),
                  activeColor: Colors.green,
                  onChanged: (value) => setSheetState(
                    () => selected = selected.withGreen(value.round()),
                  ),
                ),
                _buildColorSlider(
                  label: 'B',
                  value: (selected.b * 255).roundToDouble(),
                  activeColor: Colors.blue,
                  onChanged: (value) => setSheetState(
                    () => selected = selected.withBlue(value.round()),
                  ),
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
                        onPressed: () => Navigator.pop(context, selected),
                        child: const Text('Tanlash'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSlider({
    required String label,
    required double value,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, 255).toDouble(),
            max: 255,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(value.round().toString(), textAlign: TextAlign.right),
        ),
      ],
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

  Color _parseColor(String? raw, Color fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      return Color(int.parse(raw));
    } catch (_) {
      return fallback;
    }
  }

  String _colorToHex(Color color) {
    final hex = color
        .toARGB32()
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    return '0x$hex';
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

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

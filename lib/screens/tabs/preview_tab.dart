import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/app_models.dart';
import '../../providers/project_provider.dart';
import '../../renderer/json_renderer.dart';
import '../../utils/apk_builder.dart';
import '../../utils/dart_code_generator.dart';

class PreviewTab extends ConsumerStatefulWidget {
  const PreviewTab({super.key});

  @override
  ConsumerState<PreviewTab> createState() => _PreviewTabState();
}

class _PreviewTabState extends ConsumerState<PreviewTab> {
  String? _lastApkPath;
  String? _selectedComponentId;
  final bool _showPreviewArea = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(currentProjectProvider);
    final page = ref.watch(currentPageProvider);
    final projectIndex = ref.watch(currentProjectIndexProvider);
    final pageIndex = ref.watch(currentPageIndexProvider);

    if (project == null ||
        page == null ||
        projectIndex == null ||
        pageIndex == null) {
      return const SizedBox();
    }

    return Column(
      children: [
        if (_showPreviewArea)
          _buildComponentPanel(project, projectIndex, page, pageIndex),
        if (_showPreviewArea)
          Expanded(
            child: _buildPreviewStage(
              context,
              project,
              page,
              selectedWidgetId: _selectedComponentId,
            ),
          )
        else
          const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleRun(context, project, page),
                icon: const Icon(Icons.play_arrow),
                label: const Text('RUN (Build & Install)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              if (_lastApkPath != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Share.shareXFiles([
                          XFile(_lastApkPath!),
                        ], text: '${project.appName} APK'),
                        icon: const Icon(Icons.share),
                        label: const Text('Ulashish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showLogs(context),
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Loglar'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleExportCode(context, project),
                  icon: const Icon(Icons.file_download),
                  label: const Text('Kod (Export)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showCodePreviewSheet(context, project, page);
                  },
                  icon: const Icon(Icons.code),
                  label: const Text('Kod (Preview)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComponentPanel(
    ProjectData project,
    int projectIndex,
    PageData page,
    int pageIndex,
  ) {
    final components = _flattenWidgets(page.widgets);
    if (components.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: Colors.grey.shade100,
        alignment: Alignment.centerLeft,
        child: Text(
          'Components: hali widget qo\'shilmagan',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: Colors.grey.shade100,
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: components.length,
          separatorBuilder: (context, index) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final item = components[index];
            final selected = _selectedComponentId == item.id;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedComponentId = item.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected ? Colors.lightBlue.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? Colors.lightBlue : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${item.id} (${item.type})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeComponent(
                        project,
                        projectIndex,
                        page,
                        pageIndex,
                        item.id,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleRun(
    BuildContext context,
    ProjectData project,
    PageData page,
  ) async {
    final selectedTemplate = await _selectBuildVariant(context);
    if (selectedTemplate == null) return;
    if (!context.mounted) return;

    final statusNotifier = ValueNotifier<String>("Boshlanmoqda...");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, status, _) =>
                  Text(status, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _showLogs(context),
              child: const Text('Logs (Batafsil)'),
            ),
          ],
        ),
      ),
    );

    try {
      final path = await ApkBuilder.buildApk(
        project,
        onProgress: (msg) => statusNotifier.value = msg,
        templateAsset: selectedTemplate,
      );

      if (context.mounted) Navigator.pop(context);

      if (path != null) {
        setState(() => _lastApkPath = path);
        await ApkBuilder.installApk(path);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xatolik: APK fayli yaratilmadi.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tizim xatosi: $e')));
      }
    } finally {
      statusNotifier.dispose();
    }
  }

  Widget _buildPreviewStage(
    BuildContext context,
    ProjectData project,
    PageData page, {
    String? selectedWidgetId,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade100, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(18),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 460;
            const previewRatio = 9 / 16;

            final headerHeight = compact ? 62.0 : 72.0;
            final availableHeight = (constraints.maxHeight - headerHeight - 20)
                .clamp(200.0, 1400.0)
                .toDouble();
            final availableWidth = (constraints.maxWidth - 24)
                .clamp(220.0, 900.0)
                .toDouble();
            final widthByHeight = availableHeight * previewRatio;
            final previewWidth = widthByHeight < availableWidth
                ? widthByHeight
                : availableWidth;
            final previewHeight = previewWidth / previewRatio;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.appName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              page.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openFullPreview(context, project, page),
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: Text(compact ? 'Full' : 'Full screen'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: previewWidth,
                      height: previewHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: JsonRenderer(
                              pageData: page,
                              projectData: project,
                              isPreview: true,
                              selectedWidgetId: selectedWidgetId,
                              onWidgetTap: (id) {
                                setState(() => _selectedComponentId = id);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openFullPreview(
    BuildContext context,
    ProjectData project,
    PageData page,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => JsonRenderer(
          pageData: page,
          projectData: project,
          selectedWidgetId: _selectedComponentId,
        ),
      ),
    );
  }

  void _removeComponent(
    ProjectData project,
    int projectIndex,
    PageData page,
    int pageIndex,
    String widgetId,
  ) {
    final widgets = _removeById(page.widgets, widgetId);
    final events = page.events.removeWidget(widgetId);
    final pages = [...project.pages];
    pages[pageIndex] = page.copyWith(widgets: widgets, events: events);
    ref
        .read(projectProvider.notifier)
        .updateProject(projectIndex, project.copyWith(pages: pages));

    if (_selectedComponentId == widgetId) {
      setState(() => _selectedComponentId = null);
    }
  }

  List<WidgetData> _flattenWidgets(List<WidgetData> widgets) {
    final out = <WidgetData>[];
    for (final widget in widgets) {
      out.add(widget);
      final rawChildren = widget.properties['children'];
      if (rawChildren is List) {
        final children = rawChildren.whereType<Map>().map((entry) {
          return WidgetData.fromJson(Map<String, dynamic>.from(entry));
        }).toList();
        if (children.isNotEmpty) {
          out.addAll(_flattenWidgets(children));
        }
      }
    }
    return out;
  }

  List<WidgetData> _removeById(List<WidgetData> widgets, String id) {
    return widgets.where((item) => item.id != id).map((item) {
      final rawChildren = item.properties['children'];
      if (rawChildren is! List) return item;
      final children = rawChildren.whereType<Map>().map((entry) {
        return WidgetData.fromJson(Map<String, dynamic>.from(entry));
      }).toList();
      if (children.isEmpty) return item;
      final nextChildren = _removeById(children, id);
      return WidgetData(
        id: item.id,
        type: item.type,
        properties: {
          ...item.properties,
          'children': nextChildren.map((child) => child.toJson()).toList(),
        },
      );
    }).toList();
  }

  Future<String?> _selectBuildVariant(BuildContext context) async {
    final abiInfo = await ApkBuilder.getAbiInfo();
    final recommended = ApkBuilder.chooseTemplateFor(abiInfo);

    final options = <_BuildOption>[
      const _BuildOption(
        asset: 'assets/template_arm64.apk',
        title: 'ARM64 (64-bit)',
      ),
      const _BuildOption(
        asset: 'assets/template_armeabi_v7a.apk',
        title: 'ARMv7 (32-bit)',
      ),
      const _BuildOption(
        asset: 'assets/template_x86_64.apk',
        title: 'x86_64 (Emulator)',
      ),
      const _BuildOption(
        asset: 'assets/template.apk',
        title: 'Universal (katta hajm)',
      ),
    ];

    String selected = recommended;

    if (!context.mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Build variantini tanlang'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Telefon ABI: ${abiInfo.supported.isEmpty ? "noma'lum" : abiInfo.supported.join(", ")}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ...options.map((opt) {
                  final isRecommended = opt.asset == recommended;
                  return RadioListTile<String>(
                    value: opt.asset,
                    groupValue: selected,
                    dense: true,
                    title: Text(opt.title),
                    subtitle: isRecommended
                        ? const Text('Telefoningizga mos (Tavsiya etiladi)')
                        : null,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selected = value);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Davom etish'),
          ),
        ],
      ),
    );
  }

  void _showLogs(BuildContext context) {
    final allLogs = ApkBuilder.logs.join('\n');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Build Loglari'),
            IconButton(
              icon: const Icon(Icons.copy_all, size: 20),
              tooltip: 'Nusxalash',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: allLogs));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loglar nusxalandi')),
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              allLogs.isEmpty ? "Hozircha loglar yo'q." : allLogs,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportCode(
    BuildContext context,
    ProjectData project,
  ) async {
    try {
      final files = DartCodeGenerator.generateFlutterProjectFiles(project);
      final archive = Archive();
      for (final entry in files.entries) {
        final bytes = utf8.encode(entry.value);
        archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw Exception('ZIP yaratilmadi');
      }

      final directory = await getTemporaryDirectory();
      final safeName = _safeFileName(project.appName);
      final file = File('${directory.path}/${safeName}_flutter_source.zip');
      await file.writeAsBytes(zipBytes, flush: true);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '${project.appName} Flutter source (Android Studio)');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eksportda xatolik: $e')));
    }
  }

  void _showCodePreviewSheet(
    BuildContext context,
    ProjectData project,
    PageData initialPage,
  ) {
    final projectFiles = DartCodeGenerator.generateFlutterProjectFiles(project);
    final sortedPaths = projectFiles.keys.toList()..sort();
    var selectedPath = sortedPaths.contains('lib/main.dart')
        ? 'lib/main.dart'
        : sortedPaths.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final code = projectFiles[selectedPath] ?? '';
          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Source Code Preview',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kod nusxalandi!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final fileTree = _buildFileTree(
                        sortedPaths,
                        selectedPath,
                        onSelect: (path) {
                          setSheetState(() => selectedPath = path);
                        },
                      );
                      final codePanel = _buildCodePanel(
                        code,
                        scrollController,
                        selectedPath: selectedPath,
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            SizedBox(width: 290, child: fileTree),
                            VerticalDivider(
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            Expanded(child: codePanel),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          SizedBox(height: 190, child: fileTree),
                          Expanded(child: codePanel),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileTree(
    List<String> paths,
    String selectedPath, {
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      color: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: paths.length,
        itemBuilder: (context, index) {
          final path = paths[index];
          final isSelected = path == selectedPath;
          final parts = path.split('/');
          final depth = parts.length - 1;
          final name = parts.last;
          final ext = name.contains('.') ? name.split('.').last : '';
          final icon = switch (ext) {
            'dart' => Icons.code,
            'yaml' => Icons.tune,
            'md' => Icons.description,
            _ => Icons.insert_drive_file,
          };

          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelect(path),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: EdgeInsets.fromLTRB(8 + (depth * 12), 8, 8, 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.indigo.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.indigo : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.indigo.shade700
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCodePanel(
    String code,
    ScrollController scrollController, {
    required String selectedPath,
  }) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedPath,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            SelectableText.rich(
              _highlightDart(code),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _highlightDart(String code) {
    const base = TextStyle(color: Color(0xFFD4D4D4));
    const keyword = TextStyle(color: Color(0xFF569CD6));
    const string = TextStyle(color: Color(0xFFCE9178));
    const comment = TextStyle(color: Color(0xFF6A9955));
    const number = TextStyle(color: Color(0xFFB5CEA8));
    const type = TextStyle(color: Color(0xFF4EC9B0));

    final keywords = RegExp(
      r'\b(class|import|void|return|if|else|for|while|switch|case|break|continue|final|const|var|static|extends|implements|new|this|super|true|false|null|async|await|try|catch|throw)\b',
    );
    final types = RegExp(
      r'\b(Widget|BuildContext|MaterialApp|Scaffold|StatefulWidget|StatelessWidget|State|Color|Text|Row|Column|Padding|Container|SizedBox|Icon|ListView|Map|List|String|int|double|bool)\b',
    );
    final strings = RegExp("(\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*')");
    final comments = RegExp(r'(//.*?$|/\*[\s\S]*?\*/)', multiLine: true);
    final numbers = RegExp(r'\b\d+(\.\d+)?\b');

    final matches = <_Token>[];
    for (final m in comments.allMatches(code)) {
      matches.add(_Token(m.start, m.end, comment));
    }
    for (final m in strings.allMatches(code)) {
      matches.add(_Token(m.start, m.end, string));
    }
    for (final m in keywords.allMatches(code)) {
      matches.add(_Token(m.start, m.end, keyword));
    }
    for (final m in types.allMatches(code)) {
      matches.add(_Token(m.start, m.end, type));
    }
    for (final m in numbers.allMatches(code)) {
      matches.add(_Token(m.start, m.end, number));
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    var index = 0;
    for (final token in matches) {
      if (token.start < index) continue;
      if (token.start > index) {
        spans.add(
          TextSpan(text: code.substring(index, token.start), style: base),
        );
      }
      spans.add(
        TextSpan(
          text: code.substring(token.start, token.end),
          style: token.style,
        ),
      );
      index = token.end;
    }
    if (index < code.length) {
      spans.add(TextSpan(text: code.substring(index), style: base));
    }
    return TextSpan(style: base, children: spans);
  }

  String _safeFileName(String input) {
    final value = input
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
    return value.isEmpty ? 'flutware_project' : value;
  }
}

class _Token {
  final int start;
  final int end;
  final TextStyle style;

  const _Token(this.start, this.end, this.style);
}

class _BuildOption {
  final String asset;
  final String title;

  const _BuildOption({required this.asset, required this.title});
}

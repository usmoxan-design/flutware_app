import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_models.dart';
import '../../providers/project_provider.dart';
import '../../widgets/compact_block_editor.dart';
import '../logic_editor_screen.dart';

class UiTab extends ConsumerStatefulWidget {
  const UiTab({super.key});

  @override
  ConsumerState<UiTab> createState() => _UiTabState();
}

class _UiTabState extends ConsumerState<UiTab> {
  static const _templates = <_WidgetTemplate>[
    _WidgetTemplate(type: 'appbar', title: 'AppBar', icon: Icons.web_asset),
    _WidgetTemplate(
      type: 'single_scroll',
      title: 'SingleChildScrollView',
      icon: Icons.swap_vert,
    ),
    _WidgetTemplate(type: 'padding', title: 'Padding', icon: Icons.space_bar),
    _WidgetTemplate(
      type: 'expanded',
      title: 'Expanded',
      icon: Icons.open_in_full,
    ),
    _WidgetTemplate(type: 'row', title: 'Row', icon: Icons.view_column),
    _WidgetTemplate(type: 'column', title: 'Column', icon: Icons.view_stream),
    _WidgetTemplate(type: 'text', title: 'Text', icon: Icons.text_fields),
    _WidgetTemplate(type: 'button', title: 'Button', icon: Icons.smart_button),
    _WidgetTemplate(type: 'fab', title: 'FAB', icon: Icons.add_circle_outline),
  ];

  _PropertySheetTab _sheetTab = _PropertySheetTab.basic;
  bool _isWidgetDragging = false;

  String? get _selectedWidgetId => ref.read(selectedWidgetIdProvider);
  set _selectedWidgetId(String? value) =>
      ref.read(selectedWidgetIdProvider.notifier).state = value;

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

    final selectedId = ref.watch(selectedWidgetIdProvider);
    final selected = _findWidgetById(page.widgets, selectedId);

    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || selected == null) return;
        setState(() => _selectedWidgetId = null);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          final paletteWidth = isCompact ? 148.0 : 190.0;

          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: paletteWidth, child: _buildPalette(page)),
                  VerticalDivider(width: 1, color: Colors.grey.shade300),
                  Expanded(
                    child: _buildCanvas(
                      project,
                      page,
                      selected,
                      isCompact: isCompact,
                    ),
                  ),
                ],
              ),
              if (selected != null)
                _buildPropertySheet(
                  project,
                  projectIndex,
                  pageIndex,
                  page,
                  selected,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPalette(PageData page) {
    final hasAppBar = _flattenWidgets(
      page.widgets,
    ).any((item) => item.type == 'appbar');
    final hasFab = _flattenWidgets(
      page.widgets,
    ).any((item) => item.type == 'fab');
    final templates = _templates.where((item) {
      if (item.type == 'appbar' && hasAppBar) return false;
      if (item.type == 'fab' && hasFab) return false;
      return true;
    }).toList();

    return Container(
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              'Widgets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 190),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final tile = _buildTemplateTile(template, page);
                return LongPressDraggable<_WidgetTemplate>(
                  data: template,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(width: 160, child: tile),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: tile),
                  child: tile,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(_WidgetTemplate template, PageData page) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _addWidgetFromTemplate(template, page),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(template.icon, size: 17, color: Colors.blueGrey.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                template.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(
    ProjectData project,
    PageData page,
    WidgetData? selected, {
    required bool isCompact,
  }) {
    return DragTarget<_WidgetTemplate>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          _addWidgetFromTemplate(details.data, page),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        final pageFileName = _pageFileName(page.name);
        final primaryDark = _parseColor(project.colorPrimaryDark);
        final appBarWidget = page.widgets
            .where((item) => item.type == 'appbar')
            .cast<WidgetData?>()
            .firstOrNull;
        final fabWidget = page.widgets
            .where((item) => item.type == 'fab')
            .cast<WidgetData?>()
            .firstOrNull;
        final bodyWidgets = page.widgets
            .where(
              (item) =>
                  (appBarWidget == null || item.id != appBarWidget.id) &&
                  (fabWidget == null || item.id != fabWidget.id),
            )
            .toList();

        return GestureDetector(
          onTap: () {
            if (_selectedWidgetId != null) {
              setState(() => _selectedWidgetId = null);
            }
          },
          child: Container(
            color: isActive
                ? Colors.blue.withValues(alpha: 0.03)
                : Colors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                selected == null ? 12 : 178,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        pageFileName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Selected: ${selected.id}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.lightBlue.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    _buildMobileStatusBar(primaryDark),
                                    if (appBarWidget != null)
                                      _buildCanvasNode(appBarWidget, page),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: EdgeInsets.zero,
                                        child: bodyWidgets.isEmpty
                                            ? _buildDefaultPreview()
                                            : _buildRootWidgetList(
                                                project,
                                                page,
                                                bodyWidgets,
                                              ),
                                      ),
                                    ),
                                    _buildMobileBottomBar(primaryDark),
                                  ],
                                ),
                                if (_isWidgetDragging)
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    top: 6,
                                    child: DragTarget<_WidgetDragPayload>(
                                      onWillAcceptWithDetails: (_) => true,
                                      onAcceptWithDetails: (details) {
                                        _removeWidgetById(
                                          project,
                                          ref.read(
                                            currentProjectIndexProvider,
                                          )!,
                                          ref.read(currentPageIndexProvider)!,
                                          page,
                                          details.data.widgetId,
                                        );
                                        setState(() {
                                          _isWidgetDragging = false;
                                          _selectedWidgetId = null;
                                        });
                                      },
                                      builder: (context, candidate, _) {
                                        final active = candidate.isNotEmpty;
                                        return Container(
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: active
                                                ? Colors.red.shade700
                                                : Colors.red.shade400,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                if (fabWidget != null)
                                  Positioned(
                                    right: 10,
                                    bottom: 42,
                                    child: _buildCanvasNode(fabWidget, page),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCompact
                        ? 'Tap widget -> Property'
                        : 'Tap widget to edit properties. Select Row/Column then add to nest.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultPreview() {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: Text(
          'Bo\'sh preview',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildMobileStatusBar(Color color) {
    return Container(
      height: 22,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(
        children: [
          Text('22:50', style: TextStyle(color: Colors.white, fontSize: 10)),
          Spacer(),
          Icon(Icons.signal_cellular_alt, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Icon(Icons.wifi, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Icon(Icons.battery_std, size: 12, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(Color color) {
    return Container(
      height: 30,
      color: color.withValues(alpha: 0.15),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.crop_square, size: 14),
          Icon(Icons.circle_outlined, size: 14),
          Icon(Icons.arrow_back, size: 14),
        ],
      ),
    );
  }

  Widget _buildRootWidgetList(
    ProjectData project,
    PageData page,
    List<WidgetData> roots,
  ) {
    final children = <Widget>[
      _buildRootDropTarget(project, page, roots, insertIndex: 0),
    ];

    for (var i = 0; i < roots.length; i++) {
      final node = roots[i];
      children.add(
        LongPressDraggable<_WidgetDragPayload>(
          data: _WidgetDragPayload(widgetId: node.id),
          onDragStarted: () => setState(() => _isWidgetDragging = true),
          onDragEnd: (_) => setState(() => _isWidgetDragging = false),
          onDraggableCanceled: (_, _) =>
              setState(() => _isWidgetDragging = false),
          onDragCompleted: () => setState(() => _isWidgetDragging = false),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: _buildCanvasNode(node, page),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: _buildCanvasNode(node, page),
          ),
          child: _buildCanvasNode(node, page),
        ),
      );
      children.add(
        _buildRootDropTarget(project, page, roots, insertIndex: i + 1),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildRootDropTarget(
    ProjectData project,
    PageData page,
    List<WidgetData> roots, {
    required int insertIndex,
  }) {
    return DragTarget<_WidgetDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        _moveRootWidget(
          project,
          page,
          roots,
          details.data.widgetId,
          insertIndex,
        );
        setState(() => _isWidgetDragging = false);
      },
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          margin: const EdgeInsets.symmetric(vertical: 0.5),
          height: active ? 16 : 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: active
                ? Colors.lightBlue.withValues(alpha: 0.26)
                : Colors.transparent,
            border: Border.all(
              color: active ? Colors.lightBlue : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }

  void _moveRootWidget(
    ProjectData project,
    PageData page,
    List<WidgetData> roots,
    String widgetId,
    int insertIndex,
  ) {
    final movingIndex = roots.indexWhere((item) => item.id == widgetId);
    if (movingIndex < 0) return;
    final list = [...roots];
    final moving = list.removeAt(movingIndex);
    var target = insertIndex.clamp(0, list.length);
    if (movingIndex < insertIndex) {
      target -= 1;
    }
    if (target < 0) target = 0;
    if (target > list.length) target = list.length;
    list.insert(target, moving);

    final allWidgets = page.widgets;
    final appBarWidget = allWidgets.firstWhere(
      (item) => item.type == 'appbar',
      orElse: () => WidgetData(id: '', type: '', properties: const {}),
    );
    final fabWidget = allWidgets.firstWhere(
      (item) => item.type == 'fab',
      orElse: () => WidgetData(id: '', type: '', properties: const {}),
    );

    final rebuilt = <WidgetData>[
      if (appBarWidget.id.isNotEmpty) appBarWidget,
      ...list,
      if (fabWidget.id.isNotEmpty) fabWidget,
    ];

    final pIdx = ref.read(currentProjectIndexProvider);
    final pgIdx = ref.read(currentPageIndexProvider);
    if (pIdx == null || pgIdx == null) return;
    _updatePage(ref, project, pIdx, pgIdx, page.copyWith(widgets: rebuilt));
  }

  Widget _buildCanvasNode(WidgetData widget, PageData page, {int depth = 0}) {
    final isSelected = widget.id == _selectedWidgetId;
    final children = _childrenOf(widget);

    Widget body;
    switch (widget.type) {
      case 'appbar':
        final title = widget.properties['title']?.toString() ?? page.name;
        final color = _parseColor(
          widget.properties['backgroundColor']?.toString(),
        );
        body = Container(
          height: 38,
          width: double.infinity,
          color: color,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        break;
      case 'text':
        body = Text(
          widget.text.isEmpty ? 'TextView' : widget.text,
          style: TextStyle(
            fontSize: (widget.fontSize * 0.88).clamp(10.0, 14.0),
            color: Colors.black87,
          ),
        );
        break;
      case 'button':
        final enabled = widget.properties['enabled'] != false;
        body = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: enabled ? Colors.blue.shade600 : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.text.isEmpty ? 'Button' : widget.text,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        break;
      case 'row':
        final mainAxis = _parseMainAxisAlignment(
          widget.properties['mainAxisAlignment']?.toString(),
        );
        final crossAxis = _parseCrossAxisAlignment(
          widget.properties['crossAxisAlignment']?.toString(),
        );
        final mainSize = _parseMainAxisSize(
          widget.properties['mainAxisSize']?.toString(),
        );
        final textDirection = _parseTextDirection(
          widget.properties['textDirection']?.toString(),
        );
        final verticalDirection = _parseVerticalDirection(
          widget.properties['verticalDirection']?.toString(),
        );

        body = DragTarget<_WidgetTemplate>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              _addWidgetFromTemplate(details.data, page, parentId: widget.id),
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: children.isEmpty
                  ? const Text(
                      'Row',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: Row(
                        mainAxisSize: mainSize,
                        mainAxisAlignment: mainAxis,
                        crossAxisAlignment: crossAxis,
                        textDirection: textDirection,
                        verticalDirection: verticalDirection,
                        children: [
                          for (final child in children)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: _buildCanvasNode(
                                child,
                                page,
                                depth: depth + 1,
                              ),
                            ),
                        ],
                      ),
                    ),
            );
          },
        );
        break;
      case 'column':
        final mainAxis = _parseMainAxisAlignment(
          widget.properties['mainAxisAlignment']?.toString(),
        );
        final crossAxis = _parseCrossAxisAlignment(
          widget.properties['crossAxisAlignment']?.toString(),
        );
        final mainSize = _parseMainAxisSize(
          widget.properties['mainAxisSize']?.toString(),
        );
        final textDirection = _parseTextDirection(
          widget.properties['textDirection']?.toString(),
        );
        final verticalDirection = _parseVerticalDirection(
          widget.properties['verticalDirection']?.toString(),
        );

        body = DragTarget<_WidgetTemplate>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              _addWidgetFromTemplate(details.data, page, parentId: widget.id),
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: children.isEmpty
                  ? const Text(
                      'Column',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    )
                  : SizedBox(
                      height: 130,
                      child: Column(
                        mainAxisSize: mainSize,
                        mainAxisAlignment: mainAxis,
                        crossAxisAlignment: crossAxis,
                        textDirection: textDirection,
                        verticalDirection: verticalDirection,
                        children: [
                          for (final child in children)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _buildCanvasNode(
                                child,
                                page,
                                depth: depth + 1,
                              ),
                            ),
                        ],
                      ),
                    ),
            );
          },
        );
        break;
      case 'single_scroll':
        final direction = _parseAxis(
          widget.properties['scrollDirection']?.toString(),
        );
        body = DragTarget<_WidgetTemplate>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              _addWidgetFromTemplate(details.data, page, parentId: widget.id),
          builder: (context, candidateData, rejectedData) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SingleChildScrollView (${direction.name})',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  if (children.isEmpty)
                    const Text(
                      'Drop child',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    )
                  else
                    _buildCanvasNode(children.first, page, depth: depth + 1),
                ],
              ),
            );
          },
        );
        break;
      case 'padding':
        final rawPadding =
            (widget.properties['padding'] as num?)?.toDouble() ?? 8.0;
        body = DragTarget<_WidgetTemplate>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              _addWidgetFromTemplate(details.data, page, parentId: widget.id),
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: EdgeInsets.all(rawPadding.clamp(0.0, 32.0)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: children.isEmpty
                  ? const Text(
                      'Padding',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    )
                  : _buildCanvasNode(children.first, page, depth: depth + 1),
            );
          },
        );
        break;
      case 'expanded':
        final flex = (widget.properties['flex'] as num?)?.toInt() ?? 1;
        body = DragTarget<_WidgetTemplate>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) =>
              _addWidgetFromTemplate(details.data, page, parentId: widget.id),
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.blueGrey.shade200,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expanded(flex: $flex)',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildCanvasNode(children.first, page, depth: depth + 1),
                  ],
                ],
              ),
            );
          },
        );
        break;
      case 'fab':
        body = Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade600,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add, size: 18, color: Colors.white),
        );
        break;
      default:
        body = Text('Unknown: ${widget.type}');
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedWidgetId = widget.id;
          _sheetTab = _PropertySheetTab.basic;
        });
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: isSelected ? Colors.lightBlue : Colors.transparent,
              width: 1.5,
            ),
            color: isSelected
                ? Colors.lightBlue.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildPropertySheet(
    ProjectData project,
    int projectIndex,
    int pageIndex,
    PageData page,
    WidgetData? selected,
  ) {
    if (selected == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8EFF7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.widgets,
                      color: Colors.blueGrey.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selected.id,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedWidgetId = null),
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Yopish'),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () {
                        _removeWidgetById(
                          project,
                          projectIndex,
                          pageIndex,
                          page,
                          selected.id,
                        );
                        setState(() => _selectedWidgetId = null);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Basic'),
                      selected: _sheetTab == _PropertySheetTab.basic,
                      onSelected: (_) {
                        setState(() => _sheetTab = _PropertySheetTab.basic);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Event'),
                      selected: _sheetTab == _PropertySheetTab.event,
                      onSelected: (_) {
                        setState(() => _sheetTab = _PropertySheetTab.event);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_sheetTab == _PropertySheetTab.basic)
                  _buildBasicProperties(
                    project,
                    projectIndex,
                    pageIndex,
                    page,
                    selected,
                  )
                else
                  _buildEventProperties(
                    project,
                    projectIndex,
                    pageIndex,
                    page,
                    selected,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBasicProperties(
    ProjectData project,
    int projectIndex,
    int pageIndex,
    PageData page,
    WidgetData selected,
  ) {
    final children = _childrenOf(selected);
    final warning = _usageWarning(page.widgets, selected.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warning != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Text(warning, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(height: 10),
        ],
        if (selected.type == 'text' || selected.type == 'button') ...[
          TextFormField(
            initialValue: selected.text,
            decoration: const InputDecoration(
              labelText: 'text',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              final key = selected.type == 'text' ? 'text' : 'label';
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                key,
                value,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        if (selected.type == 'appbar') ...[
          TextFormField(
            initialValue:
                selected.properties['title']?.toString() ?? 'AppBar title',
            decoration: const InputDecoration(
              labelText: 'title',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'title',
                value,
              );
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue:
                selected.properties['backgroundColor']?.toString() ??
                '0xFF2E7D32',
            decoration: const InputDecoration(
              labelText: 'backgroundColor',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'backgroundColor',
                value,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        if (selected.type == 'button')
          SwitchListTile(
            value: selected.properties['enabled'] != false,
            title: const Text('enabled'),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'enabled',
                value,
              );
            },
          ),
        if (selected.type == 'single_scroll') ...[
          _buildEnumField(
            label: 'scrollDirection',
            value:
                selected.properties['scrollDirection']?.toString() ??
                'vertical',
            options: const ['vertical', 'horizontal'],
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'scrollDirection',
                value,
              );
            },
          ),
          _buildEnumField(
            label: 'physics',
            value: selected.properties['physics']?.toString() ?? 'clamping',
            options: const ['clamping', 'bouncing', 'never'],
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'physics',
                value,
              );
            },
          ),
          SwitchListTile(
            value: selected.properties['reverse'] == true,
            title: const Text('reverse'),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'reverse',
                value,
              );
            },
          ),
          TextFormField(
            initialValue:
                (selected.properties['padding'] as num?)?.toString() ?? '8',
            decoration: const InputDecoration(
              labelText: 'padding',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              final parsed = double.tryParse(value.trim());
              if (parsed == null) return;
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'padding',
                parsed,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        if (selected.type == 'padding') ...[
          TextFormField(
            initialValue:
                (selected.properties['padding'] as num?)?.toString() ?? '8',
            decoration: const InputDecoration(
              labelText: 'padding',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              final parsed = double.tryParse(value.trim());
              if (parsed == null) return;
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'padding',
                parsed,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        if (selected.type == 'expanded') ...[
          TextFormField(
            initialValue:
                (selected.properties['flex'] as num?)?.toString() ?? '1',
            decoration: const InputDecoration(
              labelText: 'flex',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onFieldSubmitted: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed == null || parsed < 1) return;
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'flex',
                parsed,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        if (selected.type == 'row' || selected.type == 'column') ...[
          _buildEnumField(
            label: 'mainAxisAlignment',
            value:
                selected.properties['mainAxisAlignment']?.toString() ?? 'start',
            options: const [
              'start',
              'center',
              'end',
              'spaceBetween',
              'spaceAround',
              'spaceEvenly',
            ],
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'mainAxisAlignment',
                value,
              );
            },
          ),
          _buildEnumField(
            label: 'crossAxisAlignment',
            value:
                selected.properties['crossAxisAlignment']?.toString() ??
                (selected.type == 'column' ? 'stretch' : 'center'),
            options: const ['start', 'center', 'end', 'stretch'],
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'crossAxisAlignment',
                value,
              );
            },
          ),
          _buildEnumField(
            label: 'mainAxisSize',
            value: selected.properties['mainAxisSize']?.toString() ?? 'min',
            options: const ['min', 'max'],
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'mainAxisSize',
                value,
              );
            },
          ),
          _buildEnumField(
            label: 'textDirection',
            value: selected.properties['textDirection']?.toString() ?? 'ltr',
            options: const ['ltr', 'rtl'],
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'textDirection',
                value,
              );
            },
          ),
          _buildEnumField(
            label: 'verticalDirection',
            value:
                selected.properties['verticalDirection']?.toString() ?? 'down',
            options: const ['down', 'up'],
            onChanged: (value) {
              _updateWidgetProperty(
                project,
                projectIndex,
                pageIndex,
                page,
                selected.id,
                'verticalDirection',
                value,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        if (selected.type == 'row' || selected.type == 'column')
          Text(
            'children: ${children.length}',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildEventProperties(
    ProjectData project,
    int projectIndex,
    int pageIndex,
    PageData page,
    WidgetData selected,
  ) {
    if (selected.type != 'button') {
      return Text(
        'Bu widget uchun Event mavjud emas.',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
      );
    }

    final events =
        page.events.widgets[selected.id] ?? const WidgetEventSchema();
    return Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            title: const Text('onPressed'),
            subtitle: Text('${events.onPressed.length} ta blok'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openWidgetEventEditor(
              project,
              projectIndex,
              pageIndex,
              page,
              widgetId: selected.id,
              eventName: 'onPressed',
              blocks: events.onPressed,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            title: const Text('onLongPress'),
            subtitle: Text('${events.onLongPress.length} ta blok'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openWidgetEventEditor(
              project,
              projectIndex,
              pageIndex,
              page,
              widgetId: selected.id,
              eventName: 'onLongPress',
              blocks: events.onLongPress,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addWidgetFromTemplate(
    _WidgetTemplate template,
    PageData page, {
    String? parentId,
  }) async {
    final project = ref.read(currentProjectProvider);
    final projectIndex = ref.read(currentProjectIndexProvider);
    final pageIndex = ref.read(currentPageIndexProvider);
    if (project == null || projectIndex == null || pageIndex == null) return;

    final targetParentId = parentId ?? _selectedContainerId(page.widgets);
    final parent = _findWidgetById(page.widgets, targetParentId);

    if (parent != null && !_supportsChildren(parent.type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanlangan widget child qabul qilmaydi')),
      );
      return;
    }

    if (parent != null && _acceptsSingleChild(parent.type)) {
      final existingChildren = _childrenOf(parent);
      if (existingChildren.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bitta qabul qiladi')));
        return;
      }
    }

    if ((template.type == 'appbar' || template.type == 'fab') &&
        targetParentId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu widget faqat rootda bo\'ladi')),
      );
      return;
    }

    if (template.type == 'expanded') {
      if (parent == null || (parent.type != 'row' && parent.type != 'column')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expanded faqat Row/Column ichida bo\'ladi'),
          ),
        );
        return;
      }
      if (_isInSingleScrollAncestor(page.widgets, parent.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ogohlantirish: SingleChildScrollView ichida Expanded xato beradi',
            ),
          ),
        );
      }
    }

    if (template.type == 'appbar' &&
        page.widgets.any((item) => item.type == 'appbar')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Har bir page uchun bitta AppBar yetarli'),
        ),
      );
      return;
    }
    if (template.type == 'fab' &&
        page.widgets.any((item) => item.type == 'fab')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Har bir page uchun bitta FAB yetarli')),
      );
      return;
    }

    final newWidget = _createWidgetFromTemplate(template, page);

    final widgets = targetParentId == null
        ? [...page.widgets, newWidget]
        : _insertChild(page.widgets, targetParentId, newWidget);

    _updatePage(
      ref,
      project,
      projectIndex,
      pageIndex,
      page.copyWith(widgets: widgets),
    );

    setState(() {
      _selectedWidgetId = newWidget.id;
      _sheetTab = _PropertySheetTab.basic;
    });
    HapticFeedback.selectionClick();
  }

  WidgetData _createWidgetFromTemplate(
    _WidgetTemplate template,
    PageData page,
  ) {
    final id = _nextId(page, template.type);
    switch (template.type) {
      case 'appbar':
        return WidgetData(
          id: id,
          type: 'appbar',
          properties: {
            'title': page.name,
            'backgroundColor': '0xFF2E7D32',
            'children': <Map<String, dynamic>>[],
          },
        );
      case 'single_scroll':
        return WidgetData(
          id: id,
          type: 'single_scroll',
          properties: {
            'scrollDirection': 'vertical',
            'reverse': false,
            'padding': 8.0,
            'physics': 'clamping',
            'children': <Map<String, dynamic>>[],
          },
        );
      case 'padding':
        return WidgetData(
          id: id,
          type: 'padding',
          properties: {'padding': 8.0, 'children': <Map<String, dynamic>>[]},
        );
      case 'expanded':
        return WidgetData(
          id: id,
          type: 'expanded',
          properties: {'flex': 1, 'children': <Map<String, dynamic>>[]},
        );
      case 'fab':
        return WidgetData(
          id: id,
          type: 'fab',
          properties: {'icon': 'add', 'children': <Map<String, dynamic>>[]},
        );
      case 'text':
        return WidgetData(
          id: id,
          type: 'text',
          properties: {'text': 'Text', 'fontSize': 14.0},
        );
      case 'button':
        return WidgetData(
          id: id,
          type: 'button',
          properties: {'label': 'Button', 'enabled': true},
        );
      case 'row':
        return WidgetData(
          id: id,
          type: 'row',
          properties: {
            'label': 'Row',
            'mainAxisAlignment': 'start',
            'crossAxisAlignment': 'center',
            'mainAxisSize': 'min',
            'textDirection': 'ltr',
            'verticalDirection': 'down',
            'children': <Map<String, dynamic>>[],
          },
        );
      case 'column':
      default:
        return WidgetData(
          id: id,
          type: 'column',
          properties: {
            'label': 'Column',
            'mainAxisAlignment': 'start',
            'crossAxisAlignment': 'stretch',
            'mainAxisSize': 'min',
            'textDirection': 'ltr',
            'verticalDirection': 'down',
            'children': <Map<String, dynamic>>[],
          },
        );
    }
  }

  void _openWidgetEventEditor(
    ProjectData project,
    int pIdx,
    int pgIdx,
    PageData page, {
    required String widgetId,
    required String eventName,
    required List<BlockModel> blocks,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogicEditorScreen(
          title: '$widgetId - $eventName',
          eventLabel: eventName,
          project: project,
          page: page,
          scope: BlockEditorScope.callback,
          initialBlocks: blocks,
          onSave: (newBlocks) {
            _updateWidgetEventBlocks(
              project,
              pIdx,
              pgIdx,
              page,
              widgetId,
              eventName: eventName,
              blocks: newBlocks,
            );
          },
        ),
      ),
    );
  }

  void _updateWidgetEventBlocks(
    ProjectData project,
    int pIdx,
    int pgIdx,
    PageData page,
    String widgetId, {
    required String eventName,
    required List<BlockModel> blocks,
  }) {
    final events = page.events.withWidgetEvent(widgetId, eventName, blocks);
    _updatePage(ref, project, pIdx, pgIdx, page.copyWith(events: events));
  }

  void _updateWidgetProperty(
    ProjectData project,
    int pIdx,
    int pgIdx,
    PageData page,
    String widgetId,
    String key,
    dynamic value,
  ) {
    final widgets = _updateWidgetById(page.widgets, widgetId, (old) {
      return WidgetData(
        id: old.id,
        type: old.type,
        properties: {...old.properties, key: value},
      );
    });
    _updatePage(ref, project, pIdx, pgIdx, page.copyWith(widgets: widgets));
  }

  void _removeWidgetById(
    ProjectData project,
    int pIdx,
    int pgIdx,
    PageData page,
    String widgetId,
  ) {
    final widgets = _removeById(page.widgets, widgetId);
    final events = page.events.removeWidget(widgetId);
    _updatePage(
      ref,
      project,
      pIdx,
      pgIdx,
      page.copyWith(widgets: widgets, events: events),
    );
    HapticFeedback.vibrate();
  }

  String? _selectedContainerId(List<WidgetData> widgets) {
    final selected = _findWidgetById(widgets, _selectedWidgetId);
    if (selected == null) return null;
    if (_supportsChildren(selected.type)) return selected.id;
    return null;
  }

  bool _supportsChildren(String type) {
    return type == 'row' ||
        type == 'column' ||
        type == 'single_scroll' ||
        type == 'padding' ||
        type == 'expanded';
  }

  bool _acceptsSingleChild(String type) {
    return type == 'single_scroll' || type == 'padding' || type == 'expanded';
  }

  String? _usageWarning(List<WidgetData> widgets, String widgetId) {
    final selected = _findWidgetById(widgets, widgetId);
    if (selected == null) return null;

    if (selected.type == 'expanded' &&
        _isInSingleScrollAncestor(widgets, selected.id)) {
      return 'Ogohlantirish: SingleChildScrollView ichida Expanded/Flexible xato beradi.';
    }
    return null;
  }

  bool _isInSingleScrollAncestor(List<WidgetData> widgets, String targetId) {
    bool visit(List<WidgetData> nodes, bool hasScrollAncestor) {
      for (final node in nodes) {
        final nextHasScroll = hasScrollAncestor || node.type == 'single_scroll';
        if (node.id == targetId) {
          return nextHasScroll && node.type != 'single_scroll';
        }
        final children = _childrenOf(node);
        if (children.isNotEmpty && visit(children, nextHasScroll)) {
          return true;
        }
      }
      return false;
    }

    return visit(widgets, false);
  }

  WidgetData? _findWidgetById(List<WidgetData> widgets, String? id) {
    if (id == null) return null;
    for (final widget in widgets) {
      if (widget.id == id) return widget;
      final nested = _findWidgetById(_childrenOf(widget), id);
      if (nested != null) return nested;
    }
    return null;
  }

  List<WidgetData> _insertChild(
    List<WidgetData> widgets,
    String parentId,
    WidgetData child,
  ) {
    return widgets.map((item) {
      if (item.id == parentId) {
        final children = _childrenOf(item);
        return _withChildren(item, [...children, child]);
      }
      final children = _childrenOf(item);
      if (children.isEmpty) return item;
      return _withChildren(item, _insertChild(children, parentId, child));
    }).toList();
  }

  List<WidgetData> _removeById(List<WidgetData> widgets, String id) {
    return widgets.where((item) => item.id != id).map((item) {
      final children = _childrenOf(item);
      if (children.isEmpty) return item;
      return _withChildren(item, _removeById(children, id));
    }).toList();
  }

  List<WidgetData> _updateWidgetById(
    List<WidgetData> widgets,
    String id,
    WidgetData Function(WidgetData) mapper,
  ) {
    return widgets.map((item) {
      if (item.id == id) return mapper(item);
      final children = _childrenOf(item);
      if (children.isEmpty) return item;
      return _withChildren(item, _updateWidgetById(children, id, mapper));
    }).toList();
  }

  List<WidgetData> _childrenOf(WidgetData widget) {
    final raw = widget.properties['children'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((json) {
      return WidgetData.fromJson(Map<String, dynamic>.from(json));
    }).toList();
  }

  WidgetData _withChildren(WidgetData widget, List<WidgetData> children) {
    return WidgetData(
      id: widget.id,
      type: widget.type,
      properties: {
        ...widget.properties,
        'children': children.map((child) => child.toJson()).toList(),
      },
    );
  }

  Widget _buildEnumField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isDense: true,
            value: options.contains(value) ? value : options.first,
            items: options
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (next) {
              if (next == null) return;
              onChanged(next);
            },
          ),
        ),
      ),
    );
  }

  MainAxisAlignment _parseMainAxisAlignment(String? raw) {
    switch (raw) {
      case 'center':
        return MainAxisAlignment.center;
      case 'end':
        return MainAxisAlignment.end;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      case 'start':
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String? raw) {
    switch (raw) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'start':
      default:
        return CrossAxisAlignment.start;
    }
  }

  MainAxisSize _parseMainAxisSize(String? raw) {
    return raw == 'max' ? MainAxisSize.max : MainAxisSize.min;
  }

  TextDirection _parseTextDirection(String? raw) {
    return raw == 'rtl' ? TextDirection.rtl : TextDirection.ltr;
  }

  VerticalDirection _parseVerticalDirection(String? raw) {
    return raw == 'up' ? VerticalDirection.up : VerticalDirection.down;
  }

  Axis _parseAxis(String? raw) {
    return raw == 'horizontal' ? Axis.horizontal : Axis.vertical;
  }

  String _nextId(PageData page, String type) {
    final prefix = switch (type) {
      'appbar' => 'appbar',
      'single_scroll' => 'scroll',
      'padding' => 'padding',
      'expanded' => 'expanded',
      'fab' => 'fab',
      'text' => 'text',
      'button' => 'button',
      'row' => 'row',
      'column' => 'column',
      _ => 'widget',
    };
    final all = _flattenWidgets(page.widgets).map((item) => item.id).toSet();
    var i = 1;
    while (all.contains('$prefix$i')) {
      i++;
    }
    return '$prefix$i';
  }

  List<WidgetData> _flattenWidgets(List<WidgetData> widgets) {
    final result = <WidgetData>[];
    for (final widget in widgets) {
      result.add(widget);
      final children = _childrenOf(widget);
      if (children.isNotEmpty) {
        result.addAll(_flattenWidgets(children));
      }
    }
    return result;
  }

  void _updatePage(
    WidgetRef ref,
    ProjectData project,
    int pIdx,
    int pgIdx,
    PageData newPage,
  ) {
    final pages = [...project.pages];
    pages[pgIdx] = newPage;
    ref
        .read(projectProvider.notifier)
        .updateProject(pIdx, project.copyWith(pages: pages));
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

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.green.shade700;
    try {
      return Color(int.parse(hexString));
    } catch (_) {
      return Colors.green.shade700;
    }
  }
}

enum _PropertySheetTab { basic, event }

class _WidgetTemplate {
  final String type;
  final String title;
  final IconData icon;

  const _WidgetTemplate({
    required this.type,
    required this.title,
    required this.icon,
  });
}

class _WidgetDragPayload {
  final String widgetId;

  const _WidgetDragPayload({required this.widgetId});
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

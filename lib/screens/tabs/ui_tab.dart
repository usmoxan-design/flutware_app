import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_models.dart';
import '../../providers/project_provider.dart';
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
  // Mobil preview o'lchamlarini biroz kattalashtiramiz (Standard Pixel/iPhone o'lchamlari)
  static const double _phoneWidth = 375;
  static const double _phoneHeight = 750;

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
          final paletteWidth = isCompact ? 130.0 : 165.0;

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
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final tile = _buildTemplateTile(template, page);
                return LongPressDraggable<_CanvasDragPayload>(
                  data: _CanvasDragPayload.template(template),
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
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(template.icon, size: 17, color: Colors.blueGrey.shade700),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                template.title,
                style: const TextStyle(
                  fontSize: 10,
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
    final primaryDark = _parseColor(project.colorPrimaryDark);
    final appBarWidget = page.widgets
        .where((item) => item.type == 'appbar')
        .cast<WidgetData?>()
        .firstOrNull;
    final fabWidget = page.widgets
        .where((item) => item.type == 'fab')
        .cast<WidgetData?>()
        .firstOrNull;
    final bodyWidgets = _bodyRoots(page.widgets);

    return GestureDetector(
      onTap: () {
        if (_selectedWidgetId != null) {
          setState(() => _selectedWidgetId = null);
        }
      },
      child: Container(
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            5,
            5,
            5,
            5, // PropertySheet endi ustiga chiqadi (Overlay), shuning uchun padding shart emas
          ),
          child: Column(
            // crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _pageFileName(page.name),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: DragTarget<_CanvasDragPayload>(
                  onWillAcceptWithDetails: (details) =>
                      details.data.template != null && bodyWidgets.isEmpty,
                  onAcceptWithDetails: (details) {
                    final template = details.data.template;
                    if (template == null) return;
                    if (_selectedWidgetId != null) {
                      setState(() => _selectedWidgetId = null);
                    }
                    _addWidgetFromTemplate(template, page);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final phoneDropActive = candidateData.isNotEmpty;
                    // FittedBox orqali 375x812 o'lchamli canvasni ekran markaziga sig'diramiz
                    // Bu skroll bo'lishini oldini oladi va proporsiyani saqlaydi
                    return FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: _phoneWidth,
                        height: _phoneHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          // borderRadius: BorderRadius.circular(
                          //   32,
                          // ), // Zamonaviyroq ko'rinish uchun radius
                          border: Border.all(
                            color: phoneDropActive
                                ? Colors.lightBlue
                                : Colors.grey.shade400,
                            width: phoneDropActive ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  _buildMobileStatusBar(primaryDark),
                                  if (appBarWidget != null)
                                    _buildCanvasNode(
                                      project,
                                      appBarWidget,
                                      page,
                                    ),
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.white,
                                      child: bodyWidgets.isEmpty
                                          ? _buildDefaultPreview(
                                              active: phoneDropActive,
                                            )
                                          : _buildRootWidgetList(
                                              project,
                                              page,
                                              bodyWidgets,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isWidgetDragging)
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  top: 6,
                                  child: DragTarget<_CanvasDragPayload>(
                                    onWillAcceptWithDetails: (details) =>
                                        details.data.widgetId != null,
                                    onAcceptWithDetails: (details) {
                                      final widgetId = details.data.widgetId;
                                      if (widgetId == null) return;
                                      _removeWidgetById(
                                        project,
                                        ref.read(currentProjectIndexProvider)!,
                                        ref.read(currentPageIndexProvider)!,
                                        page,
                                        widgetId,
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
                                  bottom: 12,
                                  child: _buildCanvasNode(
                                    project,
                                    fabWidget,
                                    page,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCompact
                    ? 'Tap widget -> Property'
                    : 'Widgetni telefon preview ichiga drag qiling.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultPreview({bool active = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: active
            ? Colors.lightBlue.withValues(alpha: 0.08)
            : Colors.grey.shade100,
      ),
      child: Center(
        child: Text(
          active ? 'Widgetni shu joyga tashlang' : 'Body bo\'sh',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  // Holat satrini biroz kattalashtirdik
  Widget _buildMobileStatusBar(Color color) {
    return Container(
      height: 26, // Avval 22 edi
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Text(
            '12:45',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Icon(Icons.signal_cellular_alt, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Icon(Icons.wifi, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Icon(Icons.battery_full, size: 14, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildMiniDropIndicator(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: active ? 92 : 60,
      height: 3,
      decoration: BoxDecoration(
        color: active ? Colors.lightBlue : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Widget _buildMobileBottomBar(Color color) {
  //   return Container(
  //     height: 30,
  //     color: color.withValues(alpha: 0.15),
  //     child: const Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //       children: [
  //         Icon(Icons.crop_square, size: 14),
  //         Icon(Icons.circle_outlined, size: 14),
  //         Icon(Icons.arrow_back, size: 14),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildRootWidgetList(
    ProjectData project,
    PageData page,
    List<WidgetData> roots,
  ) {
    final children = <Widget>[
      _buildRootDropTarget(project, page, roots, insertIndex: 0),
    ];

    if (roots.length > 1) {
      children.add(
        Container(
          margin: const EdgeInsets.fromLTRB(0, 2, 0, 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: const Text(
            'Body root 1 ta element qabul qiladi',
            style: TextStyle(fontSize: 10),
          ),
        ),
      );
    }

    for (var i = 0; i < roots.length; i++) {
      final node = roots[i];
      children.add(_buildCanvasNode(project, node, page));
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
    return DragTarget<_CanvasDragPayload>(
      onWillAcceptWithDetails: (details) {
        final template = details.data.template;
        if (template != null) {
          return roots.isEmpty;
        }
        final widgetId = details.data.widgetId;
        if (widgetId == null) return false;
        if (roots.any((item) => item.id == widgetId)) {
          return true;
        }
        return roots.isEmpty;
      },
      onAcceptWithDetails: (details) {
        final template = details.data.template;
        if (template != null) {
          if (roots.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Body root faqat bitta element')),
            );
            return;
          }
          if (_selectedWidgetId != null) {
            setState(() => _selectedWidgetId = null);
          }
          _addWidgetFromTemplate(template, page);
          return;
        }

        final widgetId = details.data.widgetId;
        if (widgetId == null) return;
        if (roots.any((item) => item.id == widgetId)) {
          _moveRootWidget(project, page, roots, widgetId, insertIndex);
        } else {
          _moveWidgetToRoot(project, page, widgetId, insertIndex);
        }
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
    if (roots.length <= 1) return;

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

  void _moveWidgetToRoot(
    ProjectData project,
    PageData page,
    String widgetId,
    int insertIndex,
  ) {
    final moving = _findWidgetById(page.widgets, widgetId);
    if (moving == null) return;
    if (moving.type == 'appbar' || moving.type == 'fab') return;

    final withoutMoving = _removeById(page.widgets, widgetId);
    final appBarWidget = withoutMoving
        .where((item) => item.type == 'appbar')
        .cast<WidgetData?>()
        .firstOrNull;
    final fabWidget = withoutMoving
        .where((item) => item.type == 'fab')
        .cast<WidgetData?>()
        .firstOrNull;
    final bodyRoots = withoutMoving
        .where(
          (item) =>
              (appBarWidget == null || item.id != appBarWidget.id) &&
              (fabWidget == null || item.id != fabWidget.id),
        )
        .toList();

    if (bodyRoots.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body root faqat bitta element')),
      );
      return;
    }

    final target = insertIndex.clamp(0, bodyRoots.length);
    bodyRoots.insert(target, moving);

    final rebuilt = <WidgetData>[
      if (appBarWidget != null) appBarWidget,
      ...bodyRoots,
      if (fabWidget != null) fabWidget,
    ];

    final pIdx = ref.read(currentProjectIndexProvider);
    final pgIdx = ref.read(currentPageIndexProvider);
    if (pIdx == null || pgIdx == null) return;

    _updatePage(ref, project, pIdx, pgIdx, page.copyWith(widgets: rebuilt));
  }

  void _moveWidgetToContainer(
    ProjectData project,
    PageData page,
    String widgetId,
    String targetParentId,
  ) {
    if (widgetId == targetParentId) return;

    final moving = _findWidgetById(page.widgets, widgetId);
    final targetParent = _findWidgetById(page.widgets, targetParentId);
    if (moving == null || targetParent == null) return;

    if (moving.type == 'appbar' || moving.type == 'fab') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AppBar/FAB faqat rootda bo\'ladi')),
      );
      return;
    }

    if (!_supportsChildren(targetParent.type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu layout child qabul qilmaydi')),
      );
      return;
    }

    if (_isDescendantOf(
      page.widgets,
      ancestorId: widgetId,
      targetId: targetParentId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Widget o\'z child ichiga ko\'chirilmaydi'),
        ),
      );
      return;
    }

    if (moving.type == 'expanded' &&
        targetParent.type != 'row' &&
        targetParent.type != 'column') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expanded faqat Row/Column ichida bo\'ladi'),
        ),
      );
      return;
    }

    final withoutMoving = _removeById(page.widgets, widgetId);
    final updatedParent = _findWidgetById(withoutMoving, targetParentId);
    if (updatedParent == null) return;

    if (_acceptsSingleChild(updatedParent.type) &&
        _childrenOf(updatedParent).isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu layout faqat bitta child qabul qiladi'),
        ),
      );
      return;
    }

    if (moving.type == 'expanded' &&
        _isInSingleScrollAncestor(withoutMoving, updatedParent.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ogohlantirish: SingleChildScrollView ichida Expanded xato beradi',
          ),
        ),
      );
    }

    final widgets = _insertChild(withoutMoving, targetParentId, moving);
    final pIdx = ref.read(currentProjectIndexProvider);
    final pgIdx = ref.read(currentPageIndexProvider);
    if (pIdx == null || pgIdx == null) return;

    _updatePage(ref, project, pIdx, pgIdx, page.copyWith(widgets: widgets));
  }

  bool _isDescendantOf(
    List<WidgetData> widgets, {
    required String ancestorId,
    required String targetId,
  }) {
    final ancestor = _findWidgetById(widgets, ancestorId);
    if (ancestor == null) return false;

    bool walk(List<WidgetData> nodes) {
      for (final node in nodes) {
        if (node.id == targetId) return true;
        if (walk(_childrenOf(node))) return true;
      }
      return false;
    }

    return walk(_childrenOf(ancestor));
  }

  Widget _buildCanvasNode(
    ProjectData project,
    WidgetData widget,
    PageData page, {
    int depth = 0,
  }) {
    final isSelected = widget.id == _selectedWidgetId;
    final children = _childrenOf(widget);

    Widget body;
    switch (widget.type) {
      case 'appbar':
        final title = widget.properties['title']?.toString() ?? page.name;
        final color = _parseColor(
          widget.properties['backgroundColor']?.toString(),
        );
        // AppBar balandligini 38 dan 56 ga oshirdik (Standard balandlik)
        body = Container(
          height: 56,
          width: double.infinity,
          color: color,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18, // Shrifni kattalashtirdik
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        break;
      case 'text':
        body = Text(
          widget.text.isEmpty ? 'TextView' : widget.text,
          style: TextStyle(
            // Matnni kattalashtirish uchun koeffitsientni oshirdik
            fontSize: (widget.fontSize * 1.1).clamp(12.0, 24.0),
            color: Colors.black87,
          ),
        );
        break;
      case 'button':
        final enabled = widget.properties['enabled'] != false;
        final buttonColor = _parseColor(
          widget.properties['backgroundColor']?.toString(),
          fallback: Colors.blue.shade600,
        );
        // Tugma o'lchamlarini va shrifini kattalashtirdik
        body = Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? buttonColor : buttonColor.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.text.isEmpty ? 'Button' : widget.text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
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
        final hasExpandedChild = children.any(
          (childWidget) => childWidget.type == 'expanded',
        );

        body = DragTarget<_CanvasDragPayload>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) {
            final template = details.data.template;
            if (template != null) {
              _addWidgetFromTemplate(template, page, parentId: widget.id);
              return;
            }
            final widgetId = details.data.widgetId;
            if (widgetId != null) {
              _moveWidgetToContainer(project, page, widgetId, widget.id);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: children.isEmpty
                  ? SizedBox(
                      height: 32,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildMiniDropIndicator(
                          candidateData.isNotEmpty,
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 128,
                      child: hasExpandedChild
                          ? SizedBox(
                              width: double.infinity,
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
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
                                        project,
                                        child,
                                        page,
                                        depth: depth + 1,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : Align(
                              alignment: Alignment.topLeft,
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
                                        project,
                                        child,
                                        page,
                                        depth: depth + 1,
                                      ),
                                    ),
                                ],
                              ),
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
        final hasExpandedChild = children.any(
          (childWidget) => childWidget.type == 'expanded',
        );

        body = DragTarget<_CanvasDragPayload>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) {
            final template = details.data.template;
            if (template != null) {
              _addWidgetFromTemplate(template, page, parentId: widget.id);
              return;
            }
            final widgetId = details.data.widgetId;
            if (widgetId != null) {
              _moveWidgetToContainer(project, page, widgetId, widget.id);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: children.isEmpty
                  ? SizedBox(
                      height: 56,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _buildMiniDropIndicator(
                          candidateData.isNotEmpty,
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: hasExpandedChild
                          ? SizedBox(
                              height: 128,
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: mainAxis,
                                crossAxisAlignment: crossAxis,
                                textDirection: textDirection,
                                verticalDirection: verticalDirection,
                                children: [
                                  for (final child in children)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: _buildCanvasNode(
                                        project,
                                        child,
                                        page,
                                        depth: depth + 1,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : Align(
                              alignment: Alignment.topLeft,
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
                                        project,
                                        child,
                                        page,
                                        depth: depth + 1,
                                      ),
                                    ),
                                ],
                              ),
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
        final reverse = widget.properties['reverse'] == true;
        final padding =
            (widget.properties['padding'] as num?)?.toDouble() ?? 8.0;
        body = DragTarget<_CanvasDragPayload>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) {
            final template = details.data.template;
            if (template != null) {
              _addWidgetFromTemplate(template, page, parentId: widget.id);
              return;
            }
            final widgetId = details.data.widgetId;
            if (widgetId != null) {
              _moveWidgetToContainer(project, page, widgetId, widget.id);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              width: double.infinity,
              height: direction == Axis.horizontal ? 92 : null,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: direction,
                  reverse: reverse,
                  padding: EdgeInsets.all(padding.clamp(0.0, 32.0)),
                  child: children.isEmpty
                      ? SizedBox(
                          width: direction == Axis.horizontal
                              ? 180
                              : double.infinity,
                          height: direction == Axis.vertical ? 120 : 56,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildMiniDropIndicator(
                              candidateData.isNotEmpty,
                            ),
                          ),
                        )
                      : _buildCanvasNode(
                          project,
                          children.first,
                          page,
                          depth: depth + 1,
                        ),
                ),
              ),
            );
          },
        );
        break;
      case 'padding':
        final rawPadding =
            (widget.properties['padding'] as num?)?.toDouble() ?? 0.0;
        body = DragTarget<_CanvasDragPayload>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) {
            final template = details.data.template;
            if (template != null) {
              _addWidgetFromTemplate(template, page, parentId: widget.id);
              return;
            }
            final widgetId = details.data.widgetId;
            if (widgetId != null) {
              _moveWidgetToContainer(project, page, widgetId, widget.id);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: EdgeInsets.all(rawPadding.clamp(0.0, 32.0)),
              decoration: BoxDecoration(
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? Colors.indigo
                      : Colors.grey.shade300,
                ),
              ),
              child: children.isEmpty
                  ? SizedBox(
                      height: 32,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildMiniDropIndicator(
                          candidateData.isNotEmpty,
                        ),
                      ),
                    )
                  : _buildCanvasNode(
                      project,
                      children.first,
                      page,
                      depth: depth + 1,
                    ),
            );
          },
        );
        break;
      case 'expanded':
        body = DragTarget<_CanvasDragPayload>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) {
            final template = details.data.template;
            if (template != null) {
              _addWidgetFromTemplate(template, page, parentId: widget.id);
              return;
            }
            final widgetId = details.data.widgetId;
            if (widgetId != null) {
              _moveWidgetToContainer(project, page, widgetId, widget.id);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
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
                  const SizedBox(height: 2),
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildCanvasNode(
                      project,
                      children.first,
                      page,
                      depth: depth + 1,
                    ),
                  ] else ...[
                    SizedBox(
                      height: 22,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildMiniDropIndicator(
                          candidateData.isNotEmpty,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
        break;
      case 'fab':
        // FAB o'lchamini kattalashtirdik
        body = Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add, size: 28, color: Colors.white),
        );
        break;
      default:
        body = Text('Unknown: ${widget.type}');
    }

    final selectable = GestureDetector(
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
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(color: Colors.lightBlue, width: 1.5),
                  color: Colors.lightBlue.withValues(alpha: 0.08),
                )
              : null,
          child: body,
        ),
      ),
    );

    if (widget.type == 'appbar' || widget.type == 'fab') {
      return selectable;
    }

    return LongPressDraggable<_CanvasDragPayload>(
      data: _CanvasDragPayload.widget(widget.id),
      onDragStarted: () => setState(() => _isWidgetDragging = true),
      onDragEnd: (_) => setState(() => _isWidgetDragging = false),
      onDraggableCanceled: (_, _) => setState(() => _isWidgetDragging = false),
      onDragCompleted: () => setState(() => _isWidgetDragging = false),
      feedback: Material(
        color: Colors.transparent,
        child: _buildDragFeedback(widget),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: selectable),
      child: selectable,
    );
  }

  Widget _buildDragFeedback(WidgetData widget) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blueGrey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          '${widget.id} (${widget.type})',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
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

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.transparent,
        elevation: 12,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE8EFF7), // Skrinshottagi och havorang fon
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- HEADER PART ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.settings_overscan,
                      size: 18,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selected.id,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 20),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
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
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 22,
                        color: Colors.black54,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _selectedWidgetId = null),
                      icon: const Icon(
                        Icons.save_outlined,
                        size: 22,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // --- TABS PART ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildTabBadge(
                      'Basic',
                      _sheetTab == _PropertySheetTab.basic,
                      () {
                        setState(() => _sheetTab = _PropertySheetTab.basic);
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildTabBadge('Recent', false, () {}),
                    const SizedBox(width: 10),
                    _buildTabBadge(
                      'Event',
                      _sheetTab == _PropertySheetTab.event,
                      () {
                        setState(() => _sheetTab = _PropertySheetTab.event);
                      },
                    ),
                  ],
                ),
              ),
              // --- CONTENT PART ---
              Flexible(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: SingleChildScrollView(
                    child: _sheetTab == _PropertySheetTab.basic
                        ? _buildBasicProperties(
                            project,
                            projectIndex,
                            pageIndex,
                            page,
                            selected,
                          )
                        : _buildEventProperties(
                            project,
                            projectIndex,
                            pageIndex,
                            page,
                            selected,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Skrinshottagi kabi ko'k burchakli "Badge/Chip" tablar
  Widget _buildTabBadge(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD3E4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.blue.shade800 : Colors.blueGrey,
          ),
        ),
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
    final cards = <Widget>[];

    void addAction({
      required String label,
      required String value,
      required IconData icon,
      required Future<void> Function() onTap,
    }) {
      cards.add(
        _buildPropertyAction(
          label: label,
          value: value,
          icon: icon,
          onTap: onTap,
        ),
      );
    }

    if (selected.type == 'text' || selected.type == 'button') {
      addAction(
        label: 'text',
        value: selected.text,
        icon: Icons.text_fields,
        onTap: () async {
          final value = await _showTextInputDialog(
            title: 'text',
            initial: selected.text,
          );
          if (value == null) return;
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
      );
    }

    if (selected.type == 'appbar') {
      addAction(
        label: 'title',
        value: selected.properties['title']?.toString() ?? page.name,
        icon: Icons.title,
        onTap: () async {
          final value = await _showTextInputDialog(
            title: 'AppBar title',
            initial: selected.properties['title']?.toString() ?? page.name,
          );
          if (value == null) return;
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
      );
      addAction(
        label: 'backgroundColor',
        value:
            selected.properties['backgroundColor']?.toString() ?? '0xFF2E7D32',
        icon: Icons.palette_outlined,
        onTap: () async {
          final picked = await _pickColor(
            _parseColor(
              selected.properties['backgroundColor']?.toString(),
              fallback: const Color(0xFF2E7D32),
            ),
          );
          if (picked == null) return;
          _updateWidgetProperty(
            project,
            projectIndex,
            pageIndex,
            page,
            selected.id,
            'backgroundColor',
            _colorToHex(picked),
          );
        },
      );
    }

    if (selected.type == 'button') {
      addAction(
        label: 'enabled',
        value: (selected.properties['enabled'] != false).toString(),
        icon: Icons.toggle_on_outlined,
        onTap: () async {
          final next = await _showBoolPickerDialog(
            title: 'enabled',
            current: selected.properties['enabled'] != false,
          );
          if (next == null) return;
          _updateWidgetProperty(
            project,
            projectIndex,
            pageIndex,
            page,
            selected.id,
            'enabled',
            next,
          );
        },
      );
      addAction(
        label: 'backgroundColor',
        value:
            selected.properties['backgroundColor']?.toString() ?? '0xFF1976D2',
        icon: Icons.palette_outlined,
        onTap: () async {
          final picked = await _pickColor(
            _parseColor(
              selected.properties['backgroundColor']?.toString(),
              fallback: Colors.blue.shade600,
            ),
          );
          if (picked == null) return;
          _updateWidgetProperty(
            project,
            projectIndex,
            pageIndex,
            page,
            selected.id,
            'backgroundColor',
            _colorToHex(picked),
          );
        },
      );
    }

    if (selected.type == 'single_scroll') {
      addAction(
        label: 'scrollDirection',
        value: selected.properties['scrollDirection']?.toString() ?? 'vertical',
        icon: Icons.swap_vert,
        onTap: () async {
          final value = await _showEnumPickerDialog(
            title: 'scrollDirection',
            options: const ['vertical', 'horizontal'],
            current:
                selected.properties['scrollDirection']?.toString() ??
                'vertical',
          );
          if (value == null) return;
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
      );
      addAction(
        label: 'physics',
        value: selected.properties['physics']?.toString() ?? 'clamping',
        icon: Icons.speed_outlined,
        onTap: () async {
          final value = await _showEnumPickerDialog(
            title: 'physics',
            options: const ['clamping', 'bouncing', 'never'],
            current: selected.properties['physics']?.toString() ?? 'clamping',
          );
          if (value == null) return;
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
      );
      addAction(
        label: 'reverse',
        value: (selected.properties['reverse'] == true).toString(),
        icon: Icons.sync_alt,
        onTap: () async {
          final next = await _showBoolPickerDialog(
            title: 'reverse',
            current: selected.properties['reverse'] == true,
          );
          if (next == null) return;
          _updateWidgetProperty(
            project,
            projectIndex,
            pageIndex,
            page,
            selected.id,
            'reverse',
            next,
          );
        },
      );
      addAction(
        label: 'padding',
        value: ((selected.properties['padding'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(1),
        icon: Icons.space_bar_outlined,
        onTap: () async {
          final value = await _showTextInputDialog(
            title: 'padding',
            initial: ((selected.properties['padding'] as num?)?.toDouble() ?? 0)
                .toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
            ],
          );
          if (value == null) return;
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
      );
    }

    if (selected.type == 'padding') {
      addAction(
        label: 'padding',
        value: ((selected.properties['padding'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(1),
        icon: Icons.space_bar_outlined,
        onTap: () async {
          final value = await _showTextInputDialog(
            title: 'padding',
            initial: ((selected.properties['padding'] as num?)?.toDouble() ?? 0)
                .toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
            ],
          );
          if (value == null) return;
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
      );
    }

    if (selected.type == 'expanded') {
      addAction(
        label: 'flex',
        value: ((selected.properties['flex'] as num?)?.toInt() ?? 1).toString(),
        icon: Icons.open_in_full,
        onTap: () async {
          final value = await _showTextInputDialog(
            title: 'flex',
            initial: ((selected.properties['flex'] as num?)?.toInt() ?? 1)
                .toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          );
          if (value == null) return;
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
      );
    }

    if (selected.type == 'row' || selected.type == 'column') {
      addAction(
        label: 'mainAxisAlignment',
        value: selected.properties['mainAxisAlignment']?.toString() ?? 'start',
        icon: Icons.align_horizontal_left,
        onTap: () async {
          final value = await _showEnumPickerDialog(
            title: 'mainAxisAlignment',
            options: const [
              'start',
              'center',
              'end',
              'spaceBetween',
              'spaceAround',
              'spaceEvenly',
            ],
            current:
                selected.properties['mainAxisAlignment']?.toString() ?? 'start',
          );
          if (value == null) return;
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
      );
      addAction(
        label: 'crossAxisAlignment',
        value:
            selected.properties['crossAxisAlignment']?.toString() ??
            (selected.type == 'column' ? 'stretch' : 'center'),
        icon: Icons.align_vertical_center,
        onTap: () async {
          final value = await _showEnumPickerDialog(
            title: 'crossAxisAlignment',
            options: const ['start', 'center', 'end', 'stretch'],
            current:
                selected.properties['crossAxisAlignment']?.toString() ??
                (selected.type == 'column' ? 'stretch' : 'center'),
          );
          if (value == null) return;
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
      );
      addAction(
        label: 'mainAxisSize',
        value: selected.properties['mainAxisSize']?.toString() ?? 'min',
        icon: Icons.fit_screen_outlined,
        onTap: () async {
          final value = await _showEnumPickerDialog(
            title: 'mainAxisSize',
            options: const ['min', 'max'],
            current: selected.properties['mainAxisSize']?.toString() ?? 'min',
          );
          if (value == null) return;
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
      );
      addAction(
        label: 'textDirection',
        value: selected.properties['textDirection']?.toString() ?? 'ltr',
        icon: Icons.format_textdirection_l_to_r,
        onTap: () async {
          final value = await _showEnumPickerDialog(
            title: 'textDirection',
            options: const ['ltr', 'rtl'],
            current: selected.properties['textDirection']?.toString() ?? 'ltr',
          );
          if (value == null) return;
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
      );
      addAction(
        label: 'verticalDirection',
        value: selected.properties['verticalDirection']?.toString() ?? 'down',
        icon: Icons.swap_vert_circle_outlined,
        onTap: () async {
          final value = await _showEnumPickerDialog(
            title: 'verticalDirection',
            options: const ['down', 'up'],
            current:
                selected.properties['verticalDirection']?.toString() ?? 'down',
          );
          if (value == null) return;
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
      );
      cards.add(
        _buildPropertyAction(
          label: 'children',
          value: children.length.toString(),
          icon: Icons.account_tree_outlined,
          onTap: null,
        ),
      );
    }

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
        if (cards.isEmpty)
          Text(
            'Bu widget uchun basic atribut yo\'q',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) => cards[index],
          ),
      ],
    );
  }

  Widget _buildPropertyAction({
    required String label,
    required String value,
    required IconData icon,
    Future<void> Function()? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDDE7F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF333333)),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showTextInputDialog({
    required String title,
    required String initial,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: title,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
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

  Future<String?> _showEnumPickerDialog({
    required String title,
    required List<String> options,
    required String current,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: options
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Row(
                  children: [
                    Icon(
                      item == current
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: item == current ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(item),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<bool?> _showBoolPickerDialog({
    required String title,
    required bool current,
  }) async {
    final picked = await _showEnumPickerDialog(
      title: title,
      options: const ['true', 'false'],
      current: current.toString(),
    );
    if (picked == null) return null;
    return picked == 'true';
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

    if (targetParentId == null &&
        template.type != 'appbar' &&
        template.type != 'fab' &&
        _bodyRoots(page.widgets).isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body root faqat bitta element')),
      );
      return;
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
    if (_selectedWidgetId != null) {
      setState(() => _selectedWidgetId = null);
    }
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
          properties: {
            'label': 'Button',
            'enabled': true,
            'backgroundColor': '0xFF1976D2',
          },
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

  Future<Color?> _pickColor(Color initial) {
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
                    for (final color in _defaultColors)
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

  List<WidgetData> _bodyRoots(List<WidgetData> widgets) {
    final appBarWidget = widgets
        .where((item) => item.type == 'appbar')
        .cast<WidgetData?>()
        .firstOrNull;
    final fabWidget = widgets
        .where((item) => item.type == 'fab')
        .cast<WidgetData?>()
        .firstOrNull;
    return widgets
        .where(
          (item) =>
              (appBarWidget == null || item.id != appBarWidget.id) &&
              (fabWidget == null || item.id != fabWidget.id),
        )
        .toList();
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

  Color _parseColor(String? hexString, {Color? fallback}) {
    final base = fallback ?? Colors.green.shade700;
    if (hexString == null || hexString.isEmpty) return base;
    try {
      return Color(int.parse(hexString));
    } catch (_) {
      return base;
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

class _CanvasDragPayload {
  final _WidgetTemplate? template;
  final String? widgetId;

  const _CanvasDragPayload._({this.template, this.widgetId});

  const _CanvasDragPayload.template(_WidgetTemplate value)
    : this._(template: value);

  const _CanvasDragPayload.widget(String id) : this._(widgetId: id);
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

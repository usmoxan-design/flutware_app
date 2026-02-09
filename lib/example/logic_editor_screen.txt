import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../models/block_definitions.dart';
import '../widgets/visual_block.dart';
import '../utils/dart_code_generator.dart';

class LogicEditorScreen extends StatefulWidget {
  final String title;
  final List<ActionBlock> initialActions;
  final Function(List<ActionBlock>) onSave;
  final ProjectData? project; // To get page list etc for dropdowns

  const LogicEditorScreen({
    super.key,
    required this.title,
    required this.initialActions,
    required this.onSave,
    this.project,
  });

  @override
  State<LogicEditorScreen> createState() => _LogicEditorScreenState();
}

class _LogicEditorScreenState extends State<LogicEditorScreen> {
  late List<ActionBlock> actions;
  bool isDraggingToTrash = false;
  BlockCategory selectedCategory = BlockCategory.view;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _paletteSheetOpen = false;
  StateSetter? _paletteSheetSetState;

  @override
  void initState() {
    super.initState();
    actions = List.from(widget.initialActions);
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (_searchQuery == next) return;
      setState(() => _searchQuery = next);
      _paletteSheetSetState?.call(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paletteSheetSetState = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.code, color: Colors.blue),
                tooltip: 'Kodni ko\'rish',
                onPressed: () => _showCodePreview(context),
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: 'Saqlash',
                onPressed: () {
                  widget.onSave(actions);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: isCompact
              ? _buildWorkspaceStack(showPaletteLauncher: true)
              : Row(
                  children: [
                    _buildPalette(compact: false),
                    Expanded(child: _buildWorkspaceStack()),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWorkspaceStack({bool showPaletteLauncher = false}) {
    return Stack(
      children: [
        _buildWorkspace(),
        if (isDraggingToTrash) _buildTrashArea(),
        if (showPaletteLauncher) _buildPaletteLauncher(),
      ],
    );
  }

  Widget _buildPaletteLauncher() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.small(
        heroTag: 'logic_palette_fab',
        backgroundColor: Colors.lightBlue.shade100,
        foregroundColor: Colors.indigo.shade700,
        onPressed: () => _openPaletteSheet(context),
        child: const Icon(Icons.extension),
      ),
    );
  }

  Widget _buildPalette({required bool compact}) {
    return Container(
      width: compact ? double.infinity : 260,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: compact
            ? null
            : Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          _buildPaletteHeader(compact: compact),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildBlockList(closeOnDrag: compact)),
                VerticalDivider(width: 1, color: Colors.grey.shade300),
                _buildCategoryRail(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openPaletteSheet(BuildContext context) {
    if (_paletteSheetOpen) return;
    _paletteSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.85;
        return StatefulBuilder(
          builder: (context, setModalState) {
            _paletteSheetSetState = setModalState;
            return SizedBox(
              height: height,
              child: _buildPalette(compact: true),
            );
          },
        );
      },
    ).whenComplete(() {
      _paletteSheetOpen = false;
      _paletteSheetSetState = null;
    });
  }

  Widget _buildPaletteHeader({required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, compact ? 8 : 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.extension, size: 18),
              SizedBox(width: 6),
              Text(
                'Bloklar Kutubxonasi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Blok qidirish...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRail() {
    return Container(
      width: 118,
      color: Colors.grey.shade50,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        children: BlockCategory.values.map((cat) {
          final isSelected = selectedCategory == cat;
          return InkWell(
            onTap: () {
              if (selectedCategory == cat) return;
              setState(() => selectedCategory = cat);
              _paletteSheetSetState?.call(() {});
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? cat.color : Colors.grey.shade300,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: cat.color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 26,
                    decoration: BoxDecoration(
                      color: cat.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? cat.color : Colors.grey.shade700,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    cat.icon,
                    color: isSelected ? cat.color : Colors.grey,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlockList({required bool closeOnDrag}) {
    final filtered = BlockRegistry.blocks
        .where((b) => b.category == selectedCategory)
        .where(
          (b) =>
              _searchQuery.isEmpty ||
              b.name.toLowerCase().contains(_searchQuery),
        )
        .toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('Blok topilmadi', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                selectedCategory.icon,
                size: 14,
                color: selectedCategory.color,
              ),
              const SizedBox(width: 6),
              Text(
                selectedCategory.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selectedCategory.color,
                ),
              ),
              const Spacer(),
              Text(
                '${filtered.length} blok',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        ...filtered.map(
          (def) => _buildPaletteBlock(def, closeOnDrag: closeOnDrag),
        ),
      ],
    );
  }

  Widget _buildPaletteBlock(BlockDefinition def, {required bool closeOnDrag}) {
    final preview = _createPreviewAction(def);

    return LongPressDraggable<BlockDefinition>(
      data: def,
      onDragEnd: (details) {
        if (details.wasAccepted) {
          _closePaletteIfNeeded(closeOnDrag);
        }
      },
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 240, child: VisualBlockWidget(action: preview)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.6,
        child: _buildPaletteBlockBody(preview),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showParameterDialog(def, null),
        child: _buildPaletteBlockBody(preview),
      ),
    );
  }

  void _closePaletteIfNeeded(bool closeOnDrag) {
    if (!closeOnDrag || !_paletteSheetOpen) return;
    Future.microtask(() {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  Widget _buildPaletteBlockBody(ActionBlock preview) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        width: double.infinity,
        child: VisualBlockWidget(action: preview),
      ),
    );
  }

  ActionBlock _createPreviewAction(BlockDefinition def) {
    final data = <String, dynamic>{};
    for (final p in def.parameters) {
      if (p.type == 'page' &&
          widget.project != null &&
          widget.project!.pages.isNotEmpty) {
        data[p.key] = widget.project!.pages.first.id;
      } else if (p.defaultValue != null) {
        data[p.key] = p.defaultValue;
      }
    }
    return ActionBlock(type: def.type, data: data);
  }

  Widget _buildWorkspace() {
    return DragTarget<BlockDefinition>(
      onWillAcceptWithDetails: (data) => true,
      onAcceptWithDetails: (details) {
        _showParameterDialog(details.data, null);
      },
      builder: (context, candidateData, rejectedData) {
        return CustomPaint(
          painter: _GridPainter(color: Colors.grey.shade200),
          child: Container(
            color: candidateData.isNotEmpty
                ? Colors.blue.withValues(alpha: 0.04)
                : Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: VisualBlockWidget(
                    action: ActionBlock(
                      type: 'event',
                      data: {'label': widget.title.toUpperCase()},
                    ),
                    isHat: true,
                  ),
                ),
                Expanded(
                  child: actions.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'Bloklarni shu yerga sudrab keling',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ReorderableListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final ActionBlock item = actions.removeAt(
                                oldIndex,
                              );
                              actions.insert(newIndex, item);
                            });
                          },
                          children: [
                            for (int i = 0; i < actions.length; i++)
                              _buildWorkspaceItem(
                                actions[i],
                                i,
                                actions,
                                depth: 0,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkspaceItem(
    ActionBlock action,
    int index,
    List<ActionBlock> parentList, {
    required int depth,
  }) {
    final maxWidth = _blockMaxWidth(context, depth: depth);
    return Container(
      key: ValueKey('action_${action.type}_${action.hashCode}_$index'),
      child: GestureDetector(
        onTap: () {
          final def = BlockRegistry.blocks.firstWhere(
            (b) => b.type == action.type,
          );
          _showParameterDialog(def, index, parentList: parentList);
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: VisualBlockWidget(
              action: action,
              targetPageName: _getTargetPageName(action),
              onDelete: () => setState(() => parentList.removeAt(index)),
              innerContent: (action.type == 'if' || action.type == 'if_else')
                  ? _buildNestedWorkspace(
                      action.innerActions,
                      slotTitle: 'THEN',
                      depth: depth + 1,
                    )
                  : null,
              elseContent: (action.type == 'if_else')
                  ? _buildNestedWorkspace(
                      action.elseActions,
                      slotTitle: 'ELSE',
                      depth: depth + 1,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  double _blockMaxWidth(BuildContext context, {required int depth}) {
    final screen = MediaQuery.of(context).size.width;
    final available = screen - 48 - (depth * 28);
    final max = available.clamp(220, 520);
    return max.toDouble();
  }

  Widget _buildNestedWorkspace(
    List<ActionBlock> nestedActions, {
    required String slotTitle,
    required int depth,
  }) {
    return DragTarget<BlockDefinition>(
      onWillAcceptWithDetails: (data) => true,
      onAcceptWithDetails: (details) {
        _showParameterDialog(details.data, null, parentList: nestedActions);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nestedActions.isEmpty)
                    Text(
                      active
                          ? '$slotTitle slot ichiga qo\'yib yuboring'
                          : '$slotTitle uchun blokni shu yerga sudrang',
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 9,
                      ),
                    )
                  else
                    ...nestedActions.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildWorkspaceItem(
                          entry.value,
                          entry.key,
                          nestedActions,
                          depth: depth,
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String? _getTargetPageName(ActionBlock action) {
    if (action.type != 'navigate' || widget.project == null) return null;
    final targetId = action.data['targetPageId'];
    return widget.project!.pages
        .firstWhere(
          (p) => p.id == targetId,
          orElse: () => PageData(id: '', name: 'Unknown'),
        )
        .name;
  }

  Widget _buildTrashArea() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (data) => true,
        onAcceptWithDetails: (details) {
          setState(() {
            actions.removeAt(details.data);
          });
          HapticFeedback.vibrate();
        },
        builder: (context, candidateData, rejectedData) {
          bool active = candidateData.isNotEmpty;
          return Container(
            height: 80,
            decoration: BoxDecoration(
              color: active ? Colors.red : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_sweep,
                  color: active ? Colors.white : Colors.red,
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'O\'CHIRISH UCHUN QO\'YIB YUBORING'
                      : 'O\'CHIRISH ARAVASI',
                  style: TextStyle(
                    color: active ? Colors.white : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showParameterDialog(
    BlockDefinition def,
    int? editIndex, {
    List<ActionBlock>? parentList,
  }) {
    parentList ??= actions;
    if (def.parameters.isEmpty && editIndex == null) {
      setState(() {
        parentList!.add(ActionBlock(type: def.type, data: {}));
      });
      return;
    }

    final controllers = <String, TextEditingController>{};
    String? selectedPageId;

    final existingData = editIndex != null
        ? parentList[editIndex].data
        : <String, dynamic>{};

    for (var p in def.parameters) {
      final val = existingData[p.key] ?? p.defaultValue?.toString() ?? '';
      if (p.type == 'page') {
        selectedPageId = existingData[p.key];
      } else {
        controllers[p.key] = TextEditingController(text: val.toString());
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(
            editIndex == null ? def.name : '${def.name}ni tahrirlash',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: def.parameters.map((p) {
              if (p.type == 'page') {
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: p.label),
                  initialValue: selectedPageId,
                  items:
                      widget.project?.pages
                          .map(
                            (pg) => DropdownMenuItem(
                              value: pg.id,
                              child: Text(pg.name),
                            ),
                          )
                          .toList() ??
                      [],
                  onChanged: (val) => setDlgState(() => selectedPageId = val),
                );
              }
              return TextField(
                controller: controllers[p.key],
                decoration: InputDecoration(labelText: p.label),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () {
                final data = <String, dynamic>{};
                for (var p in def.parameters) {
                  data[p.key] = p.type == 'page'
                      ? selectedPageId
                      : controllers[p.key]!.text;
                }
                setState(() {
                  if (editIndex != null) {
                    parentList![editIndex] = ActionBlock(
                      type: def.type,
                      data: data,
                      innerActions: parentList[editIndex].innerActions,
                      elseActions: parentList[editIndex].elseActions,
                    );
                  } else {
                    parentList!.add(ActionBlock(type: def.type, data: data));
                  }
                });
                Navigator.pop(context);
              },
              child: Text(editIndex == null ? 'Qo\'shish' : 'Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCodePreview(BuildContext context) {
    if (widget.project == null) return;

    final code = DartCodeGenerator.generateActionBlocksOnly(
      widget.project!,
      actions,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bloklar Kodlari (Dart)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kod nusxalandi')),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const double gap = 24;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

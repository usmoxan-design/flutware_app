import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/block_definitions.dart';

enum BlockEditorScope { onCreate, callback }

class CompactBlockEditor extends StatefulWidget {
  final String eventLabel;
  final List<BlockModel> initialBlocks;
  final ValueChanged<List<BlockModel>> onChanged;
  final List<String> widgetIds;
  final List<PageData> pages;
  final BlockEditorScope scope;

  const CompactBlockEditor({
    super.key,
    required this.eventLabel,
    required this.initialBlocks,
    required this.onChanged,
    required this.widgetIds,
    required this.pages,
    required this.scope,
  });

  @override
  State<CompactBlockEditor> createState() => _CompactBlockEditorState();
}

class _CompactBlockEditorState extends State<CompactBlockEditor> {
  late List<BlockModel> _blocks;
  BlockCategory _selectedCategory = BlockCategory.view;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool _paletteSheetOpen = false;
  bool _showDragActions = false;

  @override
  void initState() {
    super.initState();
    _blocks = _clone(widget.initialBlocks);
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (_search == next) return;
      setState(() => _search = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_paletteSheetOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_paletteSheetOpen) return;
        setState(() => _paletteSheetOpen = false);
      },
      child: Stack(
        children: [
          Container(color: const Color(0xFFF5F7FA)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEventHeader(),
                const SizedBox(height: 6),
                _buildHatBlock(),
                const SizedBox(height: 2),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildStatementList(
                      _blocks,
                      parentId: null,
                      slotKey: null,
                      depth: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_paletteSheetOpen) _buildPaletteOverlay(),
          if (_showDragActions) _buildDragActionBar(),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: '${widget.eventLabel}_fab',
              onPressed: _togglePaletteSheet,
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              child: Icon(_paletteSheetOpen ? Icons.close : Icons.extension),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteOverlay() {
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _paletteSheetOpen = false),
              child: Container(color: Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EFF7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
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
                Expanded(child: _buildPaletteSheetContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragActionBar() {
    return Positioned(
      left: 10,
      right: 10,
      top: 8,
      child: Row(
        children: [
          Expanded(
            child: _buildDragActionTarget(
              icon: Icons.delete_outline,
              label: 'Delete',
              activeColor: Colors.red.shade600,
              onAccept: (payload) => _removeBlock(payload.block.id),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildDragActionTarget(
              icon: Icons.copy_outlined,
              label: 'Duplicate',
              activeColor: Colors.indigo.shade600,
              onAccept: (payload) => _duplicateBlock(payload.block.id),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildDragActionTarget(
              icon: Icons.bookmark_border,
              label: 'Collection',
              activeColor: Colors.blueGrey.shade700,
              onAccept: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Collection keyin qo\'shiladi')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragActionTarget({
    required IconData icon,
    required String label,
    required Color activeColor,
    required ValueChanged<_DragPayload> onAccept,
  }) {
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) => details.data.fromCanvas,
      onAcceptWithDetails: (details) {
        if (!details.data.fromCanvas) return;
        onAccept(details.data);
        setState(() => _showDragActions = false);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 42,
          decoration: BoxDecoration(
            color: active ? activeColor : const Color(0xFFE7E9F0),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : Colors.black),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaletteSheetContent() {
    final defs = BlockRegistry.byCategory(_selectedCategory)
        .where(
          (item) =>
              _search.isEmpty ||
              item.title.toLowerCase().contains(_search) ||
              item.type.toLowerCase().contains(_search),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.extension, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Block palette',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _paletteSheetOpen = false),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Yopish'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Qidiruv...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: BlockCategory.values.map((category) {
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(
                      category.label,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            itemCount: defs.length,
            itemBuilder: (context, index) {
              final def = defs[index];
              return Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: _buildPaletteItem(def),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventHeader() {
    return Row(
      children: [
        Text(
          widget.eventLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        if (widget.scope == BlockEditorScope.onCreate)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text(
              '(initState)',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildHatBlock() {
    final label = widget.scope == BlockEditorScope.onCreate
        ? 'When screen created'
        : 'When ${widget.eventLabel}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          CustomPaint(
            painter: const _HatBlockPainter(
              color: Color(0xFFC87A2D),
              borderColor: Color(0xFF9D5D1E),
            ),
            child: const SizedBox(width: 236, height: 30),
          ),
          Positioned(
            left: 12,
            top: 8,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementList(
    List<BlockModel> blocks, {
    required String? parentId,
    required String? slotKey,
    required int depth,
  }) {
    if (blocks.isEmpty) {
      return _buildStatementDropTarget(
        parentId: parentId,
        slotKey: slotKey,
        insertIndex: 0,
        depth: depth,
        emptyHint: true,
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      children.add(
        _buildStatementDropTarget(
          parentId: parentId,
          slotKey: slotKey,
          insertIndex: i,
          depth: depth,
        ),
      );
      children.add(
        _buildBlockNode(
          blocks[i],
          depth: depth,
          parentId: parentId,
          slotKey: slotKey,
          index: i,
        ),
      );
    }
    children.add(
      _buildStatementDropTarget(
        parentId: parentId,
        slotKey: slotKey,
        insertIndex: blocks.length,
        depth: depth,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildStatementDropTarget({
    required String? parentId,
    required String? slotKey,
    required int insertIndex,
    required int depth,
    bool emptyHint = false,
  }) {
    final fullCover = emptyHint && parentId == null && slotKey == null;

    return Padding(
      padding: EdgeInsets.only(left: fullCover ? 0 : depth * 14.0),
      child: DragTarget<_DragPayload>(
        onWillAcceptWithDetails: (details) {
          return _canAcceptStatementDrop(
            details.data,
            parentId: parentId,
            slotKey: slotKey,
          );
        },
        onAcceptWithDetails: (details) {
          _acceptStatementDrop(
            details.data,
            parentId: parentId,
            slotKey: slotKey,
            insertIndex: insertIndex,
          );
        },
        builder: (context, candidateData, rejectedData) {
          final active = candidateData.isNotEmpty;
          final screenH = MediaQuery.of(context).size.height;
          final height = fullCover
              ? (screenH * 0.76)
              : (emptyHint ? (active ? 34.0 : 28.0) : (active ? 18.0 : 12.0));

          return AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: EdgeInsets.symmetric(vertical: fullCover ? 4 : 0.5),
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: active
                  ? Colors.lightBlue.withValues(alpha: 0.25)
                  : (emptyHint || fullCover)
                  ? Colors.grey.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(fullCover ? 14 : 8),
              border: Border.all(
                color: active ? Colors.lightBlue : Colors.transparent,
                width: active ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: fullCover
                ? Text(
                    active
                        ? 'Shu yerga tashlang'
                        : 'Blokni shu yerga olib keling',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.blue : Colors.grey.shade600,
                    ),
                  )
                : emptyHint
                ? Text(
                    active ? 'Drop here' : 'Blockni shu yerga olib keling',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: active ? Colors.blue : Colors.grey.shade600,
                    ),
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    width: active ? 92 : 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: active ? Colors.lightBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBlockNode(
    BlockModel block, {
    required int depth,
    required String? parentId,
    required String? slotKey,
    required int index,
  }) {
    final definition = BlockRegistry.get(block.type);
    final isStatement =
        (definition?.kind ?? BlockNodeKind.statement) ==
        BlockNodeKind.statement;
    if (!isStatement) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, bottom: 0.5),
      child: DragTarget<_DragPayload>(
        onWillAcceptWithDetails: (details) {
          return _canAcceptStatementDrop(
            details.data,
            parentId: parentId,
            slotKey: slotKey,
          );
        },
        onAcceptWithDetails: (details) {
          _acceptStatementDrop(
            details.data,
            parentId: parentId,
            slotKey: slotKey,
            insertIndex: index + 1,
          );
        },
        builder: (context, candidateData, rejectedData) {
          final active = candidateData.isNotEmpty;
          return LongPressDraggable<_DragPayload>(
            data: _DragPayload(block: block, fromCanvas: true),
            onDragStarted: () => setState(() => _showDragActions = true),
            onDragEnd: (_) => setState(() => _showDragActions = false),
            onDraggableCanceled: (velocity, offset) =>
                setState(() => _showDragActions = false),
            onDragCompleted: () => setState(() => _showDragActions = false),
            feedback: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Opacity(
                  opacity: 0.9,
                  child: _buildBlockBody(
                    block,
                    depth: depth,
                    snapHighlight: active,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildBlockBody(
                  block,
                  depth: depth,
                  snapHighlight: false,
                ),
              ),
            ),
            child: AnimatedScale(
              scale: active ? 1.015 : 1,
              duration: const Duration(milliseconds: 90),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildBlockBody(
                  block,
                  depth: depth,
                  snapHighlight: active,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlockBody(
    BlockModel block, {
    required int depth,
    bool snapHighlight = false,
    bool showRemove = true,
  }) {
    final definition = BlockRegistry.get(block.type);
    final category = definition?.category ?? block.category;
    final color = category.color;
    final isControl = block.type == 'if' || block.type == 'if_else';

    return Align(
      alignment: Alignment.centerLeft,
      child: IntrinsicWidth(
        child: CustomPaint(
          painter: _LegoBlockPainter(color: color, highlight: snapHighlight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: isControl ? 44 : 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        (definition?.title ?? block.type),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.scope == BlockEditorScope.onCreate &&
                          _contextOnlyTypes.contains(block.type))
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(width: 8),
                      ..._buildInputChips(block, definition),
                      if (showRemove)
                        GestureDetector(
                          onTap: () => _removeBlock(block.id),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  if (isControl) ...[
                    const SizedBox(height: 6),
                    _buildConditionSlot(block, depth + 1),
                    const SizedBox(height: 4),
                    _buildStatementSlot(block, 'then', 'then', depth + 1),
                    if (block.type == 'if_else') ...[
                      const SizedBox(height: 4),
                      _buildStatementSlot(block, 'else', 'else', depth + 1),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInputChips(BlockModel block, BlockDefinition? definition) {
    if (definition == null || definition.inputs.isEmpty) return const [];

    final chips = <Widget>[];
    for (final inputSpec in definition.inputs) {
      final input = block.inputs[inputSpec.key];
      final label = input?.block != null
          ? (BlockRegistry.get(input!.block!.type)?.title ?? input.block!.type)
          : (input?.value?.toString() ?? '').trim();

      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: InkWell(
            onTap: () => _editInputValue(block, inputSpec),
            child: Container(
              constraints: const BoxConstraints(minHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.isEmpty ? inputSpec.label : label,
                    style: TextStyle(
                      fontSize: 10,
                      color: definition.category.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 10, color: definition.category.color),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return chips;
  }

  Widget _buildConditionSlot(BlockModel parent, int depth) {
    final condition =
        (parent.slots['condition'] ?? const <BlockModel>[]).firstOrNull;

    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        return _canAcceptConditionDrop(details.data, parent.id);
      },
      onAcceptWithDetails: (details) {
        _acceptConditionDrop(details.data, parent.id);
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return Container(
          margin: EdgeInsets.only(left: depth * 6.0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
            ),
          ),
          child: condition == null
              ? Text(
                  active ? 'Drop condition' : 'Condition slot',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                )
              : _buildConditionValue(condition, parent.id),
        );
      },
    );
  }

  Widget _buildConditionValue(BlockModel block, String parentId) {
    final def = BlockRegistry.get(block.type);
    final color = (def?.category ?? block.category).color;

    return LongPressDraggable<_DragPayload>(
      data: _DragPayload(block: block, fromCanvas: true),
      onDragStarted: () => setState(() => _showDragActions = true),
      onDragEnd: (_) => setState(() => _showDragActions = false),
      onDraggableCanceled: (velocity, offset) =>
          setState(() => _showDragActions = false),
      onDragCompleted: () => setState(() => _showDragActions = false),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: _buildConditionValueBody(block, color, parentId),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildConditionValueBody(block, color, parentId),
      ),
      child: _buildConditionValueBody(block, color, parentId),
    );
  }

  Widget _buildConditionValueBody(
    BlockModel block,
    Color color,
    String parentId,
  ) {
    final def = BlockRegistry.get(block.type);
    final inputs = def?.inputs ?? const <BlockInputSpec>[];

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            def?.title ?? block.type,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          for (final input in inputs)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => _editInputValue(block, input),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    block.inputs[input.key]?.value?.toString() ?? input.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: () {
              final next = _setSingleSlot(
                _blocks,
                parentId: parentId,
                slotKey: 'condition',
                child: null,
              );
              _commit(next);
            },
            child: const Icon(Icons.close, size: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementSlot(
    BlockModel parent,
    String slotKey,
    String title,
    int depth,
  ) {
    final slotBlocks = parent.slots[slotKey] ?? const <BlockModel>[];

    return Container(
      margin: EdgeInsets.only(left: depth * 6.0),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          _buildStatementList(
            slotBlocks,
            parentId: parent.id,
            slotKey: slotKey,
            depth: depth,
          ),
        ],
      ),
    );
  }

  bool _canAcceptStatementDrop(
    _DragPayload payload, {
    required String? parentId,
    required String? slotKey,
  }) {
    final def = BlockRegistry.get(payload.block.type);
    if ((def?.kind ?? BlockNodeKind.statement) != BlockNodeKind.statement) {
      return false;
    }

    if (parentId == null) {
      return true;
    }

    final parent = _findById(_blocks, parentId);
    if (parent == null || slotKey == null) {
      return false;
    }

    if (!BlockRegistry.canDropInSlot(
      parentType: parent.type,
      slotKey: slotKey,
      childType: payload.block.type,
    )) {
      return false;
    }

    if (payload.fromCanvas && _containsId(payload.block, parentId)) {
      return false;
    }

    return true;
  }

  bool _canAcceptConditionDrop(_DragPayload payload, String parentId) {
    final def = BlockRegistry.get(payload.block.type);
    if ((def?.kind ?? BlockNodeKind.statement) != BlockNodeKind.value) {
      return false;
    }
    if (payload.fromCanvas && _containsId(payload.block, parentId)) {
      return false;
    }
    return true;
  }

  void _acceptStatementDrop(
    _DragPayload payload, {
    required String? parentId,
    required String? slotKey,
    required int insertIndex,
  }) {
    var next = _clone(_blocks);
    BlockModel toInsert = payload.block;

    if (payload.fromCanvas) {
      final removed = _removeById(next, payload.block.id);
      next = removed.blocks;
      if (removed.removed == null) return;
      toInsert = removed.removed!;
    } else {
      toInsert = BlockRegistry.cloneWithFreshIds(payload.block);
    }

    if (parentId == null) {
      final root = [...next];
      final index = insertIndex.clamp(0, root.length);
      root.insert(index, toInsert);
      _commit(root);
      return;
    }

    final inserted = _insertIntoSlot(
      next,
      parentId: parentId,
      slotKey: slotKey ?? 'then',
      index: insertIndex,
      child: toInsert,
    );
    _commit(inserted.blocks);
  }

  void _acceptConditionDrop(_DragPayload payload, String parentId) {
    var next = _clone(_blocks);
    BlockModel toInsert = payload.block;

    if (payload.fromCanvas) {
      final removed = _removeById(next, payload.block.id);
      next = removed.blocks;
      if (removed.removed == null) return;
      toInsert = removed.removed!;
    } else {
      toInsert = BlockRegistry.cloneWithFreshIds(payload.block);
    }

    final updated = _setSingleSlot(
      next,
      parentId: parentId,
      slotKey: 'condition',
      child: toInsert,
    );
    _commit(updated);
  }

  void _removeBlock(String id) {
    final next = _removeById(_blocks, id);
    _commit(next.blocks);
  }

  void _duplicateBlock(String id) {
    final source = _findById(_blocks, id);
    final location = _findLocation(_blocks, id);
    if (source == null || location == null) return;

    final clone = BlockRegistry.cloneWithFreshIds(source);
    if (location.parentId == null) {
      final root = [..._blocks];
      final nextIndex = (location.index + 1).clamp(0, root.length);
      root.insert(nextIndex, clone);
      _commit(root);
      return;
    }

    final inserted = _insertIntoSlot(
      _blocks,
      parentId: location.parentId!,
      slotKey: location.slotKey ?? 'then',
      index: location.index + 1,
      child: clone,
    );
    _commit(inserted.blocks);
  }

  _BlockLocation? _findLocation(
    List<BlockModel> source,
    String id, {
    String? parentId,
    String? slotKey,
  }) {
    for (var i = 0; i < source.length; i++) {
      final node = source[i];
      if (node.id == id) {
        return _BlockLocation(parentId: parentId, slotKey: slotKey, index: i);
      }
      for (final entry in node.slots.entries) {
        final nested = _findLocation(
          entry.value,
          id,
          parentId: node.id,
          slotKey: entry.key,
        );
        if (nested != null) return nested;
      }
    }
    return null;
  }

  void _commit(List<BlockModel> next) {
    setState(() => _blocks = _clone(next));
    widget.onChanged(_clone(next));
  }

  void _togglePaletteSheet() {
    setState(() => _paletteSheetOpen = !_paletteSheetOpen);
  }

  Widget _buildPaletteItem(BlockDefinition def) {
    final block = BlockRegistry.create(def.type);
    return LongPressDraggable<_DragPayload>(
      data: _DragPayload(block: block, fromCanvas: false),
      onDragStarted: () {
        // Drag overlay chiqib bo'lgach sheetni yopamiz.
        Future.delayed(const Duration(milliseconds: 16), () {
          if (!mounted || !_paletteSheetOpen) {
            return;
          }
          setState(() => _paletteSheetOpen = false);
        });
      },
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 250,
          child: _buildBlockBody(block, depth: 0, showRemove: false),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildPaletteItemBody(def),
      ),
      child: InkWell(
        onTap: () {
          if (def.kind == BlockNodeKind.statement) {
            _commit([..._blocks, BlockRegistry.create(def.type)]);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Operator blokni condition slotga sudrang'),
              ),
            );
          }
        },
        child: _buildPaletteItemBody(def),
      ),
    );
  }

  Widget _buildPaletteItemBody(BlockDefinition def) {
    final block = BlockRegistry.create(def.type);
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          width: 250,
          child: _buildBlockBody(block, depth: 0, showRemove: false),
        ),
      ),
    );
  }

  Future<void> _editInputValue(BlockModel block, BlockInputSpec spec) async {
    dynamic nextValue;

    switch (spec.kind) {
      case BlockInputKind.boolean:
        nextValue = await showModalBottomSheet<bool>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('true'),
                  onTap: () => Navigator.pop(context, true),
                ),
                ListTile(
                  title: const Text('false'),
                  onTap: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        );
        break;
      case BlockInputKind.widgetId:
        nextValue = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.widgetIds
                  .map(
                    (id) => ListTile(
                      title: Text(id),
                      onTap: () => Navigator.pop(context, id),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        break;
      case BlockInputKind.pageId:
        nextValue = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.pages
                  .map(
                    (page) => ListTile(
                      title: Text(page.name),
                      subtitle: Text(page.id),
                      onTap: () => Navigator.pop(context, page.id),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        break;
      case BlockInputKind.text:
        final controller = TextEditingController(
          text:
              block.inputs[spec.key]?.value?.toString() ??
              spec.defaultValue?.toString() ??
              '',
        );
        nextValue = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(spec.label),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(isDense: true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;
    }

    if (nextValue == null) return;

    final updated = _replaceById(_blocks, block.id, (old) {
      final nextInputs = <String, BlockInputModel>{...old.inputs};
      nextInputs[spec.key] = BlockInputModel(value: nextValue);
      return old.copyWith(inputs: nextInputs);
    });

    _commit(updated.blocks);
  }

  _ReplaceResult _replaceById(
    List<BlockModel> source,
    String id,
    BlockModel Function(BlockModel) mapper,
  ) {
    var changed = false;
    final out = <BlockModel>[];

    for (final node in source) {
      if (node.id == id) {
        out.add(mapper(node));
        changed = true;
        continue;
      }

      final updatedSlots = <String, List<BlockModel>>{};
      var localChange = false;
      node.slots.forEach((key, value) {
        final replaced = _replaceById(value, id, mapper);
        updatedSlots[key] = replaced.blocks;
        if (replaced.changed) {
          localChange = true;
        }
      });

      if (localChange) {
        out.add(node.copyWith(slots: updatedSlots));
        changed = true;
      } else {
        out.add(node);
      }
    }

    return _ReplaceResult(blocks: out, changed: changed);
  }

  _RemoveResult _removeById(List<BlockModel> source, String id) {
    BlockModel? removed;
    final out = <BlockModel>[];

    for (final node in source) {
      if (node.id == id) {
        removed ??= node;
        continue;
      }

      final updatedSlots = <String, List<BlockModel>>{};
      var slotChanged = false;
      node.slots.forEach((key, value) {
        final result = _removeById(value, id);
        updatedSlots[key] = result.blocks;
        if (result.removed != null) {
          removed ??= result.removed;
          slotChanged = true;
        }
      });

      if (slotChanged) {
        out.add(node.copyWith(slots: updatedSlots));
      } else {
        out.add(node);
      }
    }

    return _RemoveResult(blocks: out, removed: removed);
  }

  _InsertResult _insertIntoSlot(
    List<BlockModel> source, {
    required String parentId,
    required String slotKey,
    required int index,
    required BlockModel child,
  }) {
    var inserted = false;
    final out = <BlockModel>[];

    for (final node in source) {
      if (node.id == parentId) {
        final list = [...(node.slots[slotKey] ?? const <BlockModel>[])];
        final safeIndex = index.clamp(0, list.length);
        list.insert(safeIndex, child);
        out.add(node.copyWith(slots: {...node.slots, slotKey: list}));
        inserted = true;
        continue;
      }

      final updatedSlots = <String, List<BlockModel>>{};
      var localInserted = false;
      node.slots.forEach((key, value) {
        final result = _insertIntoSlot(
          value,
          parentId: parentId,
          slotKey: slotKey,
          index: index,
          child: child,
        );
        updatedSlots[key] = result.blocks;
        if (result.inserted) {
          localInserted = true;
        }
      });

      if (localInserted) {
        out.add(node.copyWith(slots: updatedSlots));
        inserted = true;
      } else {
        out.add(node);
      }
    }

    return _InsertResult(blocks: out, inserted: inserted);
  }

  List<BlockModel> _setSingleSlot(
    List<BlockModel> source, {
    required String parentId,
    required String slotKey,
    required BlockModel? child,
  }) {
    var changed = false;
    final out = <BlockModel>[];

    for (final node in source) {
      if (node.id == parentId) {
        changed = true;
        out.add(
          node.copyWith(
            slots: {
              ...node.slots,
              slotKey: child == null ? <BlockModel>[] : <BlockModel>[child],
            },
          ),
        );
        continue;
      }

      final updatedSlots = <String, List<BlockModel>>{};
      var localChanged = false;
      node.slots.forEach((key, value) {
        final replaced = _setSingleSlot(
          value,
          parentId: parentId,
          slotKey: slotKey,
          child: child,
        );
        updatedSlots[key] = replaced;
        if (_listChanged(value, replaced)) {
          localChanged = true;
        }
      });

      if (localChanged) {
        out.add(node.copyWith(slots: updatedSlots));
        changed = true;
      } else {
        out.add(node);
      }
    }

    return _SetSlotResult(blocks: out, changed: changed).blocks;
  }

  BlockModel? _findById(List<BlockModel> source, String id) {
    for (final node in source) {
      if (node.id == id) return node;
      for (final children in node.slots.values) {
        final nested = _findById(children, id);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  bool _containsId(BlockModel root, String targetId) {
    if (root.id == targetId) return true;
    for (final children in root.slots.values) {
      for (final child in children) {
        if (_containsId(child, targetId)) return true;
      }
    }
    return false;
  }

  bool _listChanged(List<BlockModel> oldList, List<BlockModel> newList) {
    if (oldList.length != newList.length) return true;
    for (var i = 0; i < oldList.length; i++) {
      if (oldList[i].id != newList[i].id) return true;
    }
    return false;
  }

  List<BlockModel> _clone(List<BlockModel> source) {
    return source.map((item) => BlockModel.fromJson(item.toJson())).toList();
  }
}

class _LegoBlockPainter extends CustomPainter {
  final Color color;
  final bool highlight;

  const _LegoBlockPainter({required this.color, required this.highlight});

  @override
  void paint(Canvas canvas, Size size) {
    const r = 8.0;
    const notchWidth = 20.0;
    const notchDepth = 5.0;
    const tabWidth = 22.0;
    const tabHeight = 6.0;

    final notchLeft = 16.0;
    final tabLeft = 18.0;
    final w = size.width;
    final h = size.height - tabHeight;

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(notchLeft, 0)
      ..lineTo(notchLeft, notchDepth)
      ..lineTo(notchLeft + notchWidth, notchDepth)
      ..lineTo(notchLeft + notchWidth, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(tabLeft + tabWidth, h)
      ..lineTo(tabLeft + tabWidth, h + tabHeight)
      ..lineTo(tabLeft, h + tabHeight)
      ..lineTo(tabLeft, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    final fill = Paint()..color = color;
    canvas.drawPath(path, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlight ? 2.1 : 1.2
      ..color = highlight
          ? Colors.lightBlue.withValues(alpha: 0.95)
          : color.withValues(alpha: 0.76);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _LegoBlockPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.highlight != highlight;
  }
}

class _HatBlockPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  const _HatBlockPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.42)
      ..quadraticBezierTo(w * 0.1, h * 0.02, w * 0.3, h * 0.1)
      ..quadraticBezierTo(w * 0.42, h * 0.16, w * 0.5, h * 0.16)
      ..quadraticBezierTo(w * 0.58, h * 0.16, w * 0.7, h * 0.1)
      ..quadraticBezierTo(w * 0.9, h * 0.02, w, h * 0.42)
      ..lineTo(w, h)
      ..close();

    final fill = Paint()..color = color;
    canvas.drawPath(path, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = borderColor;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _HatBlockPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}

class _DragPayload {
  final BlockModel block;
  final bool fromCanvas;

  const _DragPayload({required this.block, required this.fromCanvas});
}

class _BlockLocation {
  final String? parentId;
  final String? slotKey;
  final int index;

  const _BlockLocation({
    required this.parentId,
    required this.slotKey,
    required this.index,
  });
}

class _RemoveResult {
  final List<BlockModel> blocks;
  final BlockModel? removed;

  const _RemoveResult({required this.blocks, required this.removed});
}

class _InsertResult {
  final List<BlockModel> blocks;
  final bool inserted;

  const _InsertResult({required this.blocks, required this.inserted});
}

class _ReplaceResult {
  final List<BlockModel> blocks;
  final bool changed;

  const _ReplaceResult({required this.blocks, required this.changed});
}

class _SetSlotResult {
  final List<BlockModel> blocks;
  final bool changed;

  const _SetSlotResult({required this.blocks, required this.changed});
}

const Set<String> _contextOnlyTypes = {
  'snackbar',
  'navigate_push',
  'navigate_pop',
  'request_focus',
};

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

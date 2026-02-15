import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../models/blocks.dart';
import '../utils/dart_code_generator.dart';

import '../widgets/blockly_block_editor.dart';

class LogicEditorScreen extends StatefulWidget {
  final String title;
  final String eventLabel;
  final List<BlockModel> initialBlocks;
  final ValueChanged<List<BlockModel>> onSave;
  final ProjectData project;
  final PageData page;
  final BlockEditorScope scope;

  const LogicEditorScreen({
    super.key,
    required this.title,
    required this.eventLabel,
    required this.initialBlocks,
    required this.onSave,
    required this.project,
    required this.page,
    required this.scope,
  });

  @override
  State<LogicEditorScreen> createState() => _LogicEditorScreenState();
}

class _LogicEditorScreenState extends State<LogicEditorScreen> {
  late List<BlockModel> _draftBlocks;
  late String _initialSnapshot;
  bool _savedFromAction = false;

  @override
  void initState() {
    super.initState();
    _draftBlocks = widget.initialBlocks
        .map((item) => BlockModel.fromJson(item.toJson()))
        .toList();

    // Agar bloklar bo'sh bo'lsa, Hat blokini qo'shish
    if (_draftBlocks.isEmpty) {
      _draftBlocks.add(
        BlockDefinitions.createBlock(
          'event_hat',
          id: 'hat_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    }

    _initialSnapshot = _snapshot(_draftBlocks);
  }

  @override
  Widget build(BuildContext context) {
    final widgetIds = _collectWidgetIds(widget.page.widgets);

    return PopScope(
      canPop: _savedFromAction || !_isDirty(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _savedFromAction || !_isDirty()) {
          return;
        }
        final allow = await _handleBackPress();
        if (allow && context.mounted) {
          setState(() => _savedFromAction = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1C1E),
          centerTitle: true,
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          actions: [
            IconButton(
              onPressed: _showCodePreview,
              icon: const Icon(Icons.code_rounded),
              tooltip: 'Blok kodi',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () {
                  setState(() => _savedFromAction = true);
                  _saveDraft();
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 26,
                  color: Colors.blue,
                ),
                tooltip: 'Saqlash',
              ),
            ),
          ],
        ),

        body: BlocklyBlockEditor(
          key: ValueKey('${widget.page.id}_${widget.eventLabel}'),
          eventLabel: widget.eventLabel,
          initialBlocks: _draftBlocks,
          scope: widget.scope,

          pages: widget.project.pages,
          widgetIds: widgetIds,
          onChanged: (blocks) {
            _draftBlocks = blocks
                .map((item) => BlockModel.fromJson(item.toJson()))
                .toList();
            _saveDraft();
          },
        ),
      ),
    );
  }

  void _showCodePreview() {
    final actions = _draftBlocks.map((item) => item.toActionBlock()).toList();
    final code = DartCodeGenerator.generateActionBlocksOnly(
      widget.project,
      actions,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bloklar kodi (Dart)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kod nusxalandi')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF111315),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    code.isEmpty ? '// Bo\'sh event' : code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF9FEA8D),
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

  List<String> _collectWidgetIds(List<WidgetData> widgets) {
    final out = <String>[];

    void walk(List<WidgetData> nodes) {
      for (final node in nodes) {
        out.add(node.id);
        final rawChildren = node.properties['children'];
        if (rawChildren is List) {
          final children = rawChildren.whereType<Map>().map((item) {
            return WidgetData.fromJson(Map<String, dynamic>.from(item));
          }).toList();
          walk(children);
        }
      }
    }

    walk(widgets);
    return out;
  }

  Future<bool> _handleBackPress() async {
    if (_savedFromAction || !_isDirty()) {
      return true;
    }

    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saqlash'),
        content: const Text('Bloklar o\'zgardi. Saqlaysizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _ExitAction.cancel),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ExitAction.discard),
            child: const Text('Saqlamasdan chiqish'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _ExitAction.save),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );

    switch (action) {
      case _ExitAction.save:
        _saveDraft();
        return true;
      case _ExitAction.discard:
        return true;
      case _ExitAction.cancel:
      case null:
        return false;
    }
  }

  bool _isDirty() => _snapshot(_draftBlocks) != _initialSnapshot;

  String _snapshot(List<BlockModel> blocks) {
    return jsonEncode(blocks.map((item) => item.toJson()).toList());
  }

  void _saveDraft() {
    widget.onSave(
      _draftBlocks.map((item) => BlockModel.fromJson(item.toJson())).toList(),
    );
    _initialSnapshot = _snapshot(_draftBlocks);
  }
}

enum _ExitAction { save, discard, cancel }

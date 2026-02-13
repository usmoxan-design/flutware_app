import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blockly/flutter_blockly.dart';

import '../models/app_models.dart';
import '../utils/blockly_bridge.dart';
import 'compact_block_editor.dart';

class BlocklyBlockEditor extends StatefulWidget {
  final String eventLabel;
  final List<BlockModel> initialBlocks;
  final ValueChanged<List<BlockModel>> onChanged;
  final List<String> widgetIds;
  final List<PageData> pages;
  final BlockEditorScope scope;

  const BlocklyBlockEditor({
    super.key,
    required this.eventLabel,
    required this.initialBlocks,
    required this.onChanged,
    required this.widgetIds,
    required this.pages,
    required this.scope,
  });

  @override
  State<BlocklyBlockEditor> createState() => _BlocklyBlockEditorState();
}

class _BlocklyBlockEditorState extends State<BlocklyBlockEditor> {
  late BlocklyOptions _workspaceConfiguration;
  late Map<String, dynamic> _initialState;
  late String _script;
  late String _lastSnapshot;
  String? _runtimeError;

  bool get _isBlocklySupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant BlocklyBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_deepEquals(widget.initialBlocks, oldWidget.initialBlocks) ||
        !_deepStringListEquals(widget.widgetIds, oldWidget.widgetIds) ||
        !_deepPageListEquals(widget.pages, oldWidget.pages)) {
      _configure();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBlocklySupported) {
      return CompactBlockEditor(
        key: ValueKey('${widget.eventLabel}_${widget.scope.name}_fallback'),
        eventLabel: widget.eventLabel,
        initialBlocks: widget.initialBlocks,
        onChanged: widget.onChanged,
        widgetIds: widget.widgetIds,
        pages: widget.pages,
        scope: widget.scope,
      );
    }

    return Stack(
      children: [
        Container(
          color: const Color(0xFFF5F7FA),
          child: BlocklyEditorWidget(
            key: ValueKey('${widget.eventLabel}_${widget.scope.name}_blockly'),
            workspaceConfiguration: _workspaceConfiguration,
            initial: _initialState,
            script: _script,
            onChange: _onBlocklyChange,
            onError: (error) {
              final text = error?.toString() ?? 'Unknown Blockly error';
              if (!mounted) return;
              setState(() => _runtimeError = text);
              debugPrint('Blockly error: $text');
            },
          ),
        ),
        if (_runtimeError != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Material(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(8),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  _runtimeError!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _configure() {
    _workspaceConfiguration = BlocklyOptions.fromJson({
      'toolbox': BlocklyBridge.toolboxJson(),
      'renderer': 'zelos',
      'trashcan': true,
      'scrollbars': {'horizontal': true, 'vertical': true},
      'grid': {'spacing': 20, 'length': 3, 'colour': '#D5DEE8', 'snap': true},
      'move': {
        'drag': true,
        'wheel': true,
        'scrollbars': {'horizontal': true, 'vertical': true},
      },
      'zoom': {
        'controls': true,
        'wheel': true,
        'startScale': 0.9,
        'maxScale': 1.6,
        'minScale': 0.45,
        'scaleSpeed': 1.1,
      },
    });
    _initialState = BlocklyBridge.toBlocklyState(widget.initialBlocks);
    _script = BlocklyBridge.buildCustomScript(
      widgetIds: widget.widgetIds,
      pages: widget.pages,
    );
    _lastSnapshot = _snapshot(widget.initialBlocks);
    _runtimeError = null;
  }

  void _onBlocklyChange(dynamic data) {
    if (data is! BlocklyData) {
      return;
    }

    final next = BlocklyBridge.fromBlocklyState(data.json);
    final nextSnapshot = _snapshot(next);
    if (nextSnapshot == _lastSnapshot) {
      return;
    }
    _lastSnapshot = nextSnapshot;
    widget.onChanged(next);
  }

  String _snapshot(List<BlockModel> blocks) {
    return jsonEncode(blocks.map((item) => item.toJson()).toList());
  }

  bool _deepEquals(List<BlockModel> a, List<BlockModel> b) {
    return _snapshot(a) == _snapshot(b);
  }

  bool _deepStringListEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _deepPageListEquals(List<PageData> a, List<PageData> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = jsonEncode(a[i].toJson());
      final right = jsonEncode(b[i].toJson());
      if (left != right) return false;
    }
    return true;
  }
}

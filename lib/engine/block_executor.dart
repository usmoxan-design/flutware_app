import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/app_models.dart';

typedef BlockSetEnabled = void Function(String widgetId, bool enabled);
typedef BlockRequestFocus = void Function(String widgetId);
typedef BlockNavigatePush = void Function(String targetPage);
typedef BlockNavigatePop = void Function();

class BlockExecutionContext {
  final BuildContext context;
  final ProjectData? project;
  final bool isInitState;
  final BlockSetEnabled? onSetEnabled;
  final BlockRequestFocus? onRequestFocus;
  final BlockNavigatePush? onNavigatePush;
  final BlockNavigatePop? onNavigatePop;

  const BlockExecutionContext({
    required this.context,
    this.project,
    this.isInitState = false,
    this.onSetEnabled,
    this.onRequestFocus,
    this.onNavigatePush,
    this.onNavigatePop,
  });

  BlockExecutionContext copyWith({
    BuildContext? context,
    ProjectData? project,
    bool? isInitState,
    Object? onSetEnabled = _noValue,
    Object? onRequestFocus = _noValue,
    Object? onNavigatePush = _noValue,
    Object? onNavigatePop = _noValue,
  }) {
    return BlockExecutionContext(
      context: context ?? this.context,
      project: project ?? this.project,
      isInitState: isInitState ?? this.isInitState,
      onSetEnabled: identical(onSetEnabled, _noValue)
          ? this.onSetEnabled
          : onSetEnabled as BlockSetEnabled?,
      onRequestFocus: identical(onRequestFocus, _noValue)
          ? this.onRequestFocus
          : onRequestFocus as BlockRequestFocus?,
      onNavigatePush: identical(onNavigatePush, _noValue)
          ? this.onNavigatePush
          : onNavigatePush as BlockNavigatePush?,
      onNavigatePop: identical(onNavigatePop, _noValue)
          ? this.onNavigatePop
          : onNavigatePop as BlockNavigatePop?,
    );
  }
}

class BlockExecutor {
  static void run(List<BlockModel> blocks, BlockExecutionContext context) {
    for (final block in blocks) {
      _runStatement(block, context);
    }
  }

  static void _runStatement(BlockModel block, BlockExecutionContext context) {
    if (context.isInitState && _requiresBuildContext(block.type)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.context.mounted) return;
        _runStatement(block, context.copyWith(isInitState: false));
      });
      return;
    }

    switch (block.type) {
      case 'if':
        if (_conditionOf(block, context)) {
          run(block.slots['then'] ?? const [], context);
        }
        break;
      case 'if_else':
        if (_conditionOf(block, context)) {
          run(block.slots['then'] ?? const [], context);
        } else {
          run(block.slots['else'] ?? const [], context);
        }
        break;
      case 'toast':
        _showToastOrFallback(
          context,
          _stringify(_inputValue(block, 'message', context, fallback: '')),
        );
        break;
      case 'snackbar':
        _showSnackBar(
          context.context,
          _stringify(_inputValue(block, 'message', context, fallback: '')),
        );
        break;
      case 'navigate_push':
        final target = _stringify(
          _inputValue(block, 'targetPage', context, fallback: ''),
        );
        if (target.isEmpty) return;
        if (context.onNavigatePush != null) {
          context.onNavigatePush!(target);
        }
        break;
      case 'navigate_pop':
        if (context.onNavigatePop != null) {
          context.onNavigatePop!();
        } else if (Navigator.of(context.context).canPop()) {
          Navigator.of(context.context).pop();
        }
        break;
      case 'set_enabled':
        final widgetId = _stringify(
          _inputValue(block, 'widgetId', context, fallback: ''),
        );
        if (widgetId.isEmpty) return;
        final enabled = _toBool(
          _inputValue(block, 'enabled', context, fallback: true),
        );
        if (context.onSetEnabled != null) {
          context.onSetEnabled!(widgetId, enabled);
        }
        break;
      case 'request_focus':
        final widgetId = _stringify(
          _inputValue(block, 'widgetId', context, fallback: ''),
        );
        if (widgetId.isEmpty) return;
        context.onRequestFocus?.call(widgetId);
        break;
      case 'set_variable':
        break;
      default:
        if (BlockRegistryLegacy.isValueType(block.type)) {
          return;
        }
        debugPrint('Unknown block type: ${block.type}');
    }
  }

  static bool _conditionOf(BlockModel block, BlockExecutionContext context) {
    final conditionSlot = block.slots['condition'] ?? const <BlockModel>[];
    if (conditionSlot.isNotEmpty) {
      return _toBool(_evaluate(conditionSlot.first, context));
    }
    return _toBool(_inputValue(block, 'condition', context, fallback: true));
  }

  static dynamic _evaluate(BlockModel block, BlockExecutionContext context) {
    switch (block.type) {
      case 'bool_true':
        return true;
      case 'bool_false':
        return false;
      case 'compare_eq':
        return _compare(
          _inputValue(block, 'left', context),
          _inputValue(block, 'right', context),
          '==',
        );
      case 'compare_ne':
        return _compare(
          _inputValue(block, 'left', context),
          _inputValue(block, 'right', context),
          '!=',
        );
      case 'compare_lt':
        return _compare(
          _inputValue(block, 'left', context),
          _inputValue(block, 'right', context),
          '<',
        );
      case 'compare_lte':
        return _compare(
          _inputValue(block, 'left', context),
          _inputValue(block, 'right', context),
          '<=',
        );
      case 'compare_gt':
        return _compare(
          _inputValue(block, 'left', context),
          _inputValue(block, 'right', context),
          '>',
        );
      case 'compare_gte':
        return _compare(
          _inputValue(block, 'left', context),
          _inputValue(block, 'right', context),
          '>=',
        );
      case 'logic_and':
        return _toBool(_inputValue(block, 'left', context, fallback: false)) &&
            _toBool(_inputValue(block, 'right', context, fallback: false));
      case 'logic_or':
        return _toBool(_inputValue(block, 'left', context, fallback: false)) ||
            _toBool(_inputValue(block, 'right', context, fallback: false));
      case 'logic_not':
        return !_toBool(_inputValue(block, 'value', context, fallback: false));
      case 'string_is_empty':
        return _stringify(
          _inputValue(block, 'value', context, fallback: ''),
        ).isEmpty;
      case 'string_not_empty':
        return _stringify(
          _inputValue(block, 'value', context, fallback: ''),
        ).isNotEmpty;
      default:
        return _inputValue(block, 'value', context, fallback: false);
    }
  }

  static dynamic _inputValue(
    BlockModel block,
    String key,
    BlockExecutionContext context, {
    dynamic fallback,
  }) {
    final input = block.inputs[key];
    if (input == null) return fallback;
    if (input.block != null) {
      return _evaluate(input.block!, context);
    }
    return input.value ?? fallback;
  }

  static bool _compare(dynamic left, dynamic right, String op) {
    final leftNum = _toNum(left);
    final rightNum = _toNum(right);
    if (leftNum != null && rightNum != null) {
      switch (op) {
        case '==':
          return leftNum == rightNum;
        case '!=':
          return leftNum != rightNum;
        case '<':
          return leftNum < rightNum;
        case '<=':
          return leftNum <= rightNum;
        case '>':
          return leftNum > rightNum;
        case '>=':
          return leftNum >= rightNum;
      }
    }

    final leftText = _stringify(left);
    final rightText = _stringify(right);
    switch (op) {
      case '==':
        return leftText == rightText;
      case '!=':
        return leftText != rightText;
      case '<':
        return leftText.compareTo(rightText) < 0;
      case '<=':
        return leftText.compareTo(rightText) <= 0;
      case '>':
        return leftText.compareTo(rightText) > 0;
      case '>=':
        return leftText.compareTo(rightText) >= 0;
    }
    return false;
  }

  static num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value.trim());
    }
    return null;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final raw = value.trim().toLowerCase();
      if (raw == 'true' || raw == '1') return true;
      if (raw == 'false' || raw == '0') return false;
      return raw.isNotEmpty;
    }
    return value != null;
  }

  static String _stringify(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static bool _requiresBuildContext(String type) {
    switch (type) {
      case 'snackbar':
      case 'navigate_push':
      case 'navigate_pop':
      case 'request_focus':
        return true;
      default:
        return false;
    }
  }

  static void _showToastOrFallback(
    BlockExecutionContext context,
    String message,
  ) {
    try {
      Fluttertoast.showToast(msg: message);
    } catch (_) {
      if (context.context.mounted) {
        _showSnackBar(context.context, message);
      }
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class BlockRegistryLegacy {
  static bool isValueType(String type) {
    switch (type) {
      case 'bool_true':
      case 'bool_false':
      case 'compare_eq':
      case 'compare_ne':
      case 'compare_lt':
      case 'compare_lte':
      case 'compare_gt':
      case 'compare_gte':
      case 'logic_and':
      case 'logic_or':
      case 'logic_not':
      case 'string_is_empty':
      case 'string_not_empty':
        return true;
      default:
        return false;
    }
  }
}

const Object _noValue = Object();

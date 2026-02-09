import 'package:flutter/material.dart';

import 'app_models.dart';

enum BlockNodeKind { statement, value }

enum BlockInputKind { text, boolean, widgetId, pageId }

class BlockInputSpec {
  final String key;
  final String label;
  final BlockInputKind kind;
  final dynamic defaultValue;
  final bool allowBlock;

  const BlockInputSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.defaultValue,
    this.allowBlock = false,
  });
}

class BlockSlotSpec {
  final String key;
  final String label;
  final BlockNodeKind accepts;
  final bool multiple;

  const BlockSlotSpec({
    required this.key,
    required this.label,
    required this.accepts,
    this.multiple = true,
  });
}

class BlockDefinition {
  final String type;
  final String title;
  final BlockCategory category;
  final BlockNodeKind kind;
  final List<BlockInputSpec> inputs;
  final List<BlockSlotSpec> slots;

  const BlockDefinition({
    required this.type,
    required this.title,
    required this.category,
    required this.kind,
    this.inputs = const [],
    this.slots = const [],
  });
}

extension BlockCategoryVisualExt on BlockCategory {
  Color get color => switch (this) {
    BlockCategory.variable => const Color(0xFFFF8A65),
    BlockCategory.control => const Color(0xFFF4B400),
    BlockCategory.operator => const Color(0xFF2E7D32),
    BlockCategory.view => const Color(0xFF1E88E5),
  };

  IconData get icon => switch (this) {
    BlockCategory.variable => Icons.data_object,
    BlockCategory.control => Icons.account_tree,
    BlockCategory.operator => Icons.functions,
    BlockCategory.view => Icons.visibility,
  };
}

class BlockRegistry {
  static int _idSeed = 0;

  static const List<BlockDefinition> definitions = [
    BlockDefinition(
      type: 'set_variable',
      title: 'set variable',
      category: BlockCategory.variable,
      kind: BlockNodeKind.statement,
      inputs: [
        BlockInputSpec(
          key: 'name',
          label: 'name',
          kind: BlockInputKind.text,
          defaultValue: 'value',
        ),
        BlockInputSpec(
          key: 'value',
          label: 'value',
          kind: BlockInputKind.text,
          defaultValue: '0',
        ),
      ],
    ),
    BlockDefinition(
      type: 'if',
      title: 'if',
      category: BlockCategory.control,
      kind: BlockNodeKind.statement,
      slots: [
        BlockSlotSpec(
          key: 'condition',
          label: 'condition',
          accepts: BlockNodeKind.value,
          multiple: false,
        ),
        BlockSlotSpec(
          key: 'then',
          label: 'then',
          accepts: BlockNodeKind.statement,
        ),
      ],
    ),
    BlockDefinition(
      type: 'if_else',
      title: 'if else',
      category: BlockCategory.control,
      kind: BlockNodeKind.statement,
      slots: [
        BlockSlotSpec(
          key: 'condition',
          label: 'condition',
          accepts: BlockNodeKind.value,
          multiple: false,
        ),
        BlockSlotSpec(
          key: 'then',
          label: 'then',
          accepts: BlockNodeKind.statement,
        ),
        BlockSlotSpec(
          key: 'else',
          label: 'else',
          accepts: BlockNodeKind.statement,
        ),
      ],
    ),
    BlockDefinition(
      type: 'compare_eq',
      title: '==',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.text,
          defaultValue: '1',
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.text,
          defaultValue: '1',
        ),
      ],
    ),
    BlockDefinition(
      type: 'compare_ne',
      title: '!=',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.text,
          defaultValue: '1',
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.text,
          defaultValue: '2',
        ),
      ],
    ),
    BlockDefinition(
      type: 'compare_lt',
      title: '<',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.text,
          defaultValue: '1',
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.text,
          defaultValue: '2',
        ),
      ],
    ),
    BlockDefinition(
      type: 'compare_lte',
      title: '<=',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.text,
          defaultValue: '1',
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.text,
          defaultValue: '2',
        ),
      ],
    ),
    BlockDefinition(
      type: 'compare_gt',
      title: '>',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.text,
          defaultValue: '2',
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.text,
          defaultValue: '1',
        ),
      ],
    ),
    BlockDefinition(
      type: 'compare_gte',
      title: '>=',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.text,
          defaultValue: '2',
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.text,
          defaultValue: '1',
        ),
      ],
    ),
    BlockDefinition(
      type: 'logic_and',
      title: 'and',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.boolean,
          defaultValue: true,
          allowBlock: true,
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.boolean,
          defaultValue: true,
          allowBlock: true,
        ),
      ],
    ),
    BlockDefinition(
      type: 'logic_or',
      title: 'or',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'left',
          label: 'a',
          kind: BlockInputKind.boolean,
          defaultValue: true,
          allowBlock: true,
        ),
        BlockInputSpec(
          key: 'right',
          label: 'b',
          kind: BlockInputKind.boolean,
          defaultValue: false,
          allowBlock: true,
        ),
      ],
    ),
    BlockDefinition(
      type: 'logic_not',
      title: 'not',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'value',
          label: 'value',
          kind: BlockInputKind.boolean,
          defaultValue: true,
          allowBlock: true,
        ),
      ],
    ),
    BlockDefinition(
      type: 'bool_true',
      title: 'true',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
    ),
    BlockDefinition(
      type: 'bool_false',
      title: 'false',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
    ),
    BlockDefinition(
      type: 'string_is_empty',
      title: 'is empty',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'value',
          label: 'text',
          kind: BlockInputKind.text,
          defaultValue: '',
        ),
      ],
    ),
    BlockDefinition(
      type: 'string_not_empty',
      title: 'not empty',
      category: BlockCategory.operator,
      kind: BlockNodeKind.value,
      inputs: [
        BlockInputSpec(
          key: 'value',
          label: 'text',
          kind: BlockInputKind.text,
          defaultValue: 'abc',
        ),
      ],
    ),
    BlockDefinition(
      type: 'toast',
      title: 'Toast',
      category: BlockCategory.view,
      kind: BlockNodeKind.statement,
      inputs: [
        BlockInputSpec(
          key: 'message',
          label: 'message',
          kind: BlockInputKind.text,
          defaultValue: 'Hello',
        ),
      ],
    ),
    BlockDefinition(
      type: 'snackbar',
      title: 'Snackbar',
      category: BlockCategory.view,
      kind: BlockNodeKind.statement,
      inputs: [
        BlockInputSpec(
          key: 'message',
          label: 'message',
          kind: BlockInputKind.text,
          defaultValue: 'Saved',
        ),
      ],
    ),
    BlockDefinition(
      type: 'set_enabled',
      title: 'setEnabled',
      category: BlockCategory.view,
      kind: BlockNodeKind.statement,
      inputs: [
        BlockInputSpec(
          key: 'widgetId',
          label: 'widget',
          kind: BlockInputKind.widgetId,
          defaultValue: 'button1',
        ),
        BlockInputSpec(
          key: 'enabled',
          label: 'enabled',
          kind: BlockInputKind.boolean,
          defaultValue: true,
          allowBlock: true,
        ),
      ],
    ),
    BlockDefinition(
      type: 'request_focus',
      title: 'requestFocus',
      category: BlockCategory.view,
      kind: BlockNodeKind.statement,
      inputs: [
        BlockInputSpec(
          key: 'widgetId',
          label: 'widget',
          kind: BlockInputKind.widgetId,
          defaultValue: 'button1',
        ),
      ],
    ),
    BlockDefinition(
      type: 'navigate_push',
      title: 'Navigator.push',
      category: BlockCategory.view,
      kind: BlockNodeKind.statement,
      inputs: [
        BlockInputSpec(
          key: 'targetPage',
          label: 'target',
          kind: BlockInputKind.pageId,
          defaultValue: '',
        ),
      ],
    ),
    BlockDefinition(
      type: 'navigate_pop',
      title: 'Navigator.pop',
      category: BlockCategory.view,
      kind: BlockNodeKind.statement,
    ),
  ];

  static List<BlockDefinition> byCategory(BlockCategory category) {
    return definitions.where((item) => item.category == category).toList();
  }

  static BlockDefinition? get(String type) {
    for (final def in definitions) {
      if (def.type == type) return def;
    }
    return null;
  }

  static BlockModel create(String type, {String? id}) {
    final def = get(type);
    if (def == null) {
      return BlockModel(
        id: id ?? _nextId('block'),
        type: type,
        category: BlockCategory.view,
      );
    }

    final inputs = <String, BlockInputModel>{};
    for (final input in def.inputs) {
      inputs[input.key] = BlockInputModel(value: input.defaultValue);
    }

    final slots = <String, List<BlockModel>>{};
    for (final slot in def.slots) {
      slots[slot.key] = <BlockModel>[];
    }

    return BlockModel(
      id: id ?? _nextId(type),
      type: def.type,
      category: def.category,
      inputs: inputs,
      slots: slots,
    );
  }

  static BlockModel cloneWithFreshIds(BlockModel block) {
    return BlockModel(
      id: _nextId(block.type),
      type: block.type,
      category: block.category,
      inputs: block.inputs.map(
        (key, value) => MapEntry(
          key,
          BlockInputModel(
            value: value.value,
            block: value.block == null ? null : cloneWithFreshIds(value.block!),
          ),
        ),
      ),
      slots: block.slots.map(
        (key, list) => MapEntry(key, list.map(cloneWithFreshIds).toList()),
      ),
      next: block.next == null ? null : cloneWithFreshIds(block.next!),
    );
  }

  static bool isStatementType(String type) {
    final def = get(type);
    return (def?.kind ?? BlockNodeKind.statement) == BlockNodeKind.statement;
  }

  static bool isValueType(String type) {
    final def = get(type);
    return (def?.kind ?? BlockNodeKind.statement) == BlockNodeKind.value;
  }

  static bool canDropInSlot({
    required String parentType,
    required String slotKey,
    required String childType,
  }) {
    final parent = get(parentType);
    if (parent == null) return false;

    final slot = parent.slots.where((item) => item.key == slotKey).firstOrNull;
    if (slot == null) return false;

    final childDef = get(childType);
    final childKind =
        childDef?.kind ??
        (isValueType(childType)
            ? BlockNodeKind.value
            : BlockNodeKind.statement);

    return slot.accepts == childKind;
  }

  static String _nextId(String prefix) {
    _idSeed++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idSeed';
  }
}

extension _FirstWhereOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

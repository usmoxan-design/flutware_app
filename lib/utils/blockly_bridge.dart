import 'dart:convert';

import '../models/app_models.dart';
import '../models/block_definitions.dart';

class BlocklyBridge {
  static const Set<String> _statementTypes = {
    'set_variable',
    'if',
    'if_else',
    'toast',
    'snackbar',
    'set_enabled',
    'request_focus',
    'navigate_push',
    'navigate_pop',
  };

  static const Set<String> _valueTypes = {
    'compare_eq',
    'compare_ne',
    'compare_lt',
    'compare_lte',
    'compare_gt',
    'compare_gte',
    'logic_and',
    'logic_or',
    'logic_not',
    'bool_true',
    'bool_false',
    'string_is_empty',
    'string_not_empty',
  };

  static Set<String> get _supportedTypes => {
    ..._statementTypes,
    ..._valueTypes,
  };

  static Map<String, dynamic> toolboxJson() {
    return {
      'kind': 'categoryToolbox',
      'contents': [
        {
          'kind': 'category',
          'name': 'Variable',
          'colour': '#FF8A65',
          'contents': [
            {'kind': 'block', 'type': 'set_variable'},
          ],
        },
        {
          'kind': 'category',
          'name': 'Control',
          'colour': '#F4B400',
          'contents': [
            {'kind': 'block', 'type': 'if'},
            {'kind': 'block', 'type': 'if_else'},
          ],
        },
        {
          'kind': 'category',
          'name': 'Operator',
          'colour': '#2E7D32',
          'contents': [
            {'kind': 'block', 'type': 'compare_eq'},
            {'kind': 'block', 'type': 'compare_ne'},
            {'kind': 'block', 'type': 'compare_lt'},
            {'kind': 'block', 'type': 'compare_lte'},
            {'kind': 'block', 'type': 'compare_gt'},
            {'kind': 'block', 'type': 'compare_gte'},
            {'kind': 'block', 'type': 'logic_and'},
            {'kind': 'block', 'type': 'logic_or'},
            {'kind': 'block', 'type': 'logic_not'},
            {'kind': 'block', 'type': 'bool_true'},
            {'kind': 'block', 'type': 'bool_false'},
            {'kind': 'block', 'type': 'string_is_empty'},
            {'kind': 'block', 'type': 'string_not_empty'},
          ],
        },
        {
          'kind': 'category',
          'name': 'View',
          'colour': '#1E88E5',
          'contents': [
            {'kind': 'block', 'type': 'toast'},
            {'kind': 'block', 'type': 'snackbar'},
            {'kind': 'block', 'type': 'set_enabled'},
            {'kind': 'block', 'type': 'request_focus'},
            {'kind': 'block', 'type': 'navigate_push'},
            {'kind': 'block', 'type': 'navigate_pop'},
          ],
        },
      ],
    };
  }

  static String buildCustomScript({
    required List<String> widgetIds,
    required List<PageData> pages,
  }) {
    final defaultWidgetId = (widgetIds.isEmpty ? 'button1' : widgetIds.first)
        .trim();
    final defaultPageId = (pages.isEmpty ? '' : pages.first.id).trim();
    final blocksJson = jsonEncode(
      _customBlockJsonArray(
        defaultWidgetId: defaultWidgetId.isEmpty ? 'button1' : defaultWidgetId,
        defaultPageId: defaultPageId,
      ),
    );
    final statementTypesJson = jsonEncode(_statementTypes.toList());
    final valueTypesJson = jsonEncode(_valueTypes.toList());

    return '''
<script>
(() => {
  if (typeof Blockly === 'undefined') return;

  const customBlocks = $blocksJson;
  if (Blockly.common && Blockly.common.defineBlocksWithJsonArray) {
    Blockly.common.defineBlocksWithJsonArray(customBlocks);
  } else if (Blockly.defineBlocksWithJsonArray) {
    Blockly.defineBlocksWithJsonArray(customBlocks);
  }

  const statementTypes = $statementTypesJson;
  const valueTypes = $valueTypesJson;

  const registerGenerator = (generator) => {
    if (!generator) return;
    if (!generator.forBlock) {
      generator.forBlock = {};
    }

    for (const type of statementTypes) {
      generator.forBlock[type] = function() {
        return '';
      };
    }

    for (const type of valueTypes) {
      generator.forBlock[type] = function() {
        return ['true', 0];
      };
    }
  };

  registerGenerator(window.dart && window.dart.dartGenerator);
  registerGenerator(window.javascript && window.javascript.javascriptGenerator);
  registerGenerator(window.lua && window.lua.luaGenerator);
  registerGenerator(window.php && window.php.phpGenerator);
  registerGenerator(window.python && window.python.pythonGenerator);
})();
</script>
''';
  }

  static Map<String, dynamic> toBlocklyState(List<BlockModel> blocks) {
    final chain = _statementListToChain(blocks);
    final out = <Map<String, dynamic>>[];
    if (chain != null) {
      chain['x'] = 32;
      chain['y'] = 24;
      out.add(chain);
    }

    return {
      'blocks': {'languageVersion': 0, 'blocks': out},
    };
  }

  static List<BlockModel> fromBlocklyState(Map<String, dynamic>? state) {
    final blocksNode = _asMap(state?['blocks']);
    final rawRoots = blocksNode?['blocks'];
    if (rawRoots is! List) {
      return const [];
    }

    final roots = rawRoots
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    roots.sort((a, b) => _numFrom(a['y']).compareTo(_numFrom(b['y'])));

    final out = <BlockModel>[];
    for (final root in roots) {
      out.addAll(_parseStatementChain(root));
    }
    return out;
  }

  static List<Map<String, dynamic>> _customBlockJsonArray({
    required String defaultWidgetId,
    required String defaultPageId,
  }) {
    return [
      {
        'type': 'set_variable',
        'message0': 'set variable name %1 value %2',
        'args0': [
          {'type': 'field_input', 'name': 'NAME', 'text': 'value'},
          {'type': 'field_input', 'name': 'VALUE', 'text': '0'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 20,
      },
      {
        'type': 'if',
        'message0': 'if %1',
        'args0': [
          {'type': 'input_value', 'name': 'CONDITION', 'check': 'Boolean'},
        ],
        'message1': 'then %1',
        'args1': [
          {'type': 'input_statement', 'name': 'THEN'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 45,
      },
      {
        'type': 'if_else',
        'message0': 'if %1',
        'args0': [
          {'type': 'input_value', 'name': 'CONDITION', 'check': 'Boolean'},
        ],
        'message1': 'then %1',
        'args1': [
          {'type': 'input_statement', 'name': 'THEN'},
        ],
        'message2': 'else %1',
        'args2': [
          {'type': 'input_statement', 'name': 'ELSE'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 45,
      },
      {
        'type': 'compare_eq',
        'message0': '%1 == %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '1'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_ne',
        'message0': '%1 != %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '2'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_lt',
        'message0': '%1 < %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '2'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_lte',
        'message0': '%1 <= %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '2'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_gt',
        'message0': '%1 > %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '2'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '1'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_gte',
        'message0': '%1 >= %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '2'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '1'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'logic_and',
        'message0': '%1 and %2',
        'args0': [
          {'type': 'input_value', 'name': 'LEFT', 'check': 'Boolean'},
          {'type': 'input_value', 'name': 'RIGHT', 'check': 'Boolean'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'logic_or',
        'message0': '%1 or %2',
        'args0': [
          {'type': 'input_value', 'name': 'LEFT', 'check': 'Boolean'},
          {'type': 'input_value', 'name': 'RIGHT', 'check': 'Boolean'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'logic_not',
        'message0': 'not %1',
        'args0': [
          {'type': 'input_value', 'name': 'VALUE', 'check': 'Boolean'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'bool_true',
        'message0': 'true',
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'bool_false',
        'message0': 'false',
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'string_is_empty',
        'message0': 'is empty %1',
        'args0': [
          {'type': 'field_input', 'name': 'VALUE', 'text': ''},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'string_not_empty',
        'message0': 'not empty %1',
        'args0': [
          {'type': 'field_input', 'name': 'VALUE', 'text': 'abc'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'toast',
        'message0': 'Toast %1',
        'args0': [
          {'type': 'field_input', 'name': 'MESSAGE', 'text': 'Hello'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'snackbar',
        'message0': 'Snackbar %1',
        'args0': [
          {'type': 'field_input', 'name': 'MESSAGE', 'text': 'Saved'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'set_enabled',
        'message0': 'setEnabled widget %1 enabled %2',
        'args0': [
          {'type': 'field_input', 'name': 'WIDGET', 'text': defaultWidgetId},
          {'type': 'input_value', 'name': 'ENABLED', 'check': 'Boolean'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'request_focus',
        'message0': 'requestFocus widget %1',
        'args0': [
          {'type': 'field_input', 'name': 'WIDGET', 'text': defaultWidgetId},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'navigate_push',
        'message0': 'Navigator.push target %1',
        'args0': [
          {'type': 'field_input', 'name': 'TARGET', 'text': defaultPageId},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'navigate_pop',
        'message0': 'Navigator.pop',
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
    ];
  }

  static Map<String, dynamic>? _statementListToChain(List<BlockModel> blocks) {
    final statements = blocks
        .where((item) => _supportedTypes.contains(item.type))
        .where((item) => BlockRegistry.isStatementType(item.type))
        .toList();
    if (statements.isEmpty) {
      return null;
    }

    final root = _blockToJson(statements.first);
    var current = root;
    for (var i = 1; i < statements.length; i++) {
      final next = _blockToJson(statements[i]);
      current['next'] = {'block': next};
      current = next;
    }
    return root;
  }

  static Map<String, dynamic> _blockToJson(BlockModel block) {
    final out = <String, dynamic>{'type': block.type, 'id': block.id};

    switch (block.type) {
      case 'set_variable':
        out['fields'] = {
          'NAME': _stringInput(block, 'name', fallback: 'value'),
          'VALUE': _stringInput(block, 'value', fallback: '0'),
        };
        break;
      case 'if':
      case 'if_else':
        final inputs = <String, dynamic>{};
        final condition =
            (block.slots['condition'] ?? const <BlockModel>[]).firstOrNull;
        if (condition != null && _valueTypes.contains(condition.type)) {
          inputs['CONDITION'] = {'block': _blockToJson(condition)};
        }
        final thenChain = _statementListToChain(
          block.slots['then'] ?? const <BlockModel>[],
        );
        if (thenChain != null) {
          inputs['THEN'] = {'block': thenChain};
        }
        if (block.type == 'if_else') {
          final elseChain = _statementListToChain(
            block.slots['else'] ?? const <BlockModel>[],
          );
          if (elseChain != null) {
            inputs['ELSE'] = {'block': elseChain};
          }
        }
        if (inputs.isNotEmpty) {
          out['inputs'] = inputs;
        }
        break;
      case 'toast':
      case 'snackbar':
        out['fields'] = {
          'MESSAGE': _stringInput(block, 'message', fallback: ''),
        };
        break;
      case 'set_enabled':
        out['fields'] = {
          'WIDGET': _stringInput(block, 'widgetId', fallback: 'button1'),
        };
        out['inputs'] = {
          'ENABLED': _booleanInputNode(
            block.inputs['enabled'],
            fallback: _boolInput(block, 'enabled', fallback: true),
          ),
        };
        break;
      case 'request_focus':
        out['fields'] = {
          'WIDGET': _stringInput(block, 'widgetId', fallback: 'button1'),
        };
        break;
      case 'navigate_push':
        out['fields'] = {
          'TARGET': _stringInput(block, 'targetPage', fallback: ''),
        };
        break;
      case 'navigate_pop':
        break;
      case 'compare_eq':
      case 'compare_ne':
      case 'compare_lt':
      case 'compare_lte':
      case 'compare_gt':
      case 'compare_gte':
        out['fields'] = {
          'LEFT': _stringInput(block, 'left', fallback: '1'),
          'RIGHT': _stringInput(block, 'right', fallback: '1'),
        };
        break;
      case 'logic_and':
      case 'logic_or':
        out['inputs'] = {
          'LEFT': _booleanInputNode(
            block.inputs['left'],
            fallback: _boolInput(block, 'left', fallback: true),
          ),
          'RIGHT': _booleanInputNode(
            block.inputs['right'],
            fallback: _boolInput(block, 'right', fallback: true),
          ),
        };
        break;
      case 'logic_not':
        out['inputs'] = {
          'VALUE': _booleanInputNode(
            block.inputs['value'],
            fallback: _boolInput(block, 'value', fallback: true),
          ),
        };
        break;
      case 'bool_true':
      case 'bool_false':
        break;
      case 'string_is_empty':
      case 'string_not_empty':
        out['fields'] = {'VALUE': _stringInput(block, 'value', fallback: '')};
        break;
      default:
        break;
    }

    return out;
  }

  static List<BlockModel> _parseStatementChain(Map<String, dynamic> root) {
    final out = <BlockModel>[];
    Map<String, dynamic>? current = root;
    while (current != null) {
      final parsed = _parseBlock(current);
      if (parsed != null && _statementTypes.contains(parsed.type)) {
        out.add(parsed);
      }
      current = _nextBlock(current);
    }
    return out;
  }

  static BlockModel? _parseBlock(Map<String, dynamic> block) {
    final type = block['type']?.toString();
    if (type == null || !_supportedTypes.contains(type)) {
      return null;
    }

    final base = BlockRegistry.create(type, id: _blockId(block, type));
    final nextInputs = <String, BlockInputModel>{...base.inputs};
    final nextSlots = <String, List<BlockModel>>{
      for (final entry in base.slots.entries) entry.key: [...entry.value],
    };

    switch (type) {
      case 'set_variable':
        nextInputs['name'] = BlockInputModel(
          value: _fieldText(
            block,
            'NAME',
            fallback: _defaultInput(base, 'name', fallback: 'value'),
          ),
        );
        nextInputs['value'] = BlockInputModel(
          value: _fieldText(
            block,
            'VALUE',
            fallback: _defaultInput(base, 'value', fallback: '0'),
          ),
        );
        break;
      case 'if':
      case 'if_else':
        final conditionBlock = _parseValueInput(block, 'CONDITION');
        nextSlots['condition'] = conditionBlock == null
            ? <BlockModel>[]
            : <BlockModel>[conditionBlock];

        final thenStart = _inputBlock(block, 'THEN');
        nextSlots['then'] = thenStart == null
            ? <BlockModel>[]
            : _parseStatementChain(thenStart);

        if (type == 'if_else') {
          final elseStart = _inputBlock(block, 'ELSE');
          nextSlots['else'] = elseStart == null
              ? <BlockModel>[]
              : _parseStatementChain(elseStart);
        }
        break;
      case 'toast':
      case 'snackbar':
        nextInputs['message'] = BlockInputModel(
          value: _fieldText(
            block,
            'MESSAGE',
            fallback: _defaultInput(base, 'message', fallback: ''),
          ),
        );
        break;
      case 'set_enabled':
        nextInputs['widgetId'] = BlockInputModel(
          value: _fieldText(
            block,
            'WIDGET',
            fallback: _defaultInput(base, 'widgetId', fallback: 'button1'),
          ),
        );
        nextInputs['enabled'] = _parseBooleanInput(
          block,
          'ENABLED',
          fallback: _defaultBool(base, 'enabled', fallback: true),
        );
        break;
      case 'request_focus':
        nextInputs['widgetId'] = BlockInputModel(
          value: _fieldText(
            block,
            'WIDGET',
            fallback: _defaultInput(base, 'widgetId', fallback: 'button1'),
          ),
        );
        break;
      case 'navigate_push':
        nextInputs['targetPage'] = BlockInputModel(
          value: _fieldText(
            block,
            'TARGET',
            fallback: _defaultInput(base, 'targetPage', fallback: ''),
          ),
        );
        break;
      case 'navigate_pop':
        break;
      case 'compare_eq':
      case 'compare_ne':
      case 'compare_lt':
      case 'compare_lte':
      case 'compare_gt':
      case 'compare_gte':
        nextInputs['left'] = BlockInputModel(
          value: _fieldText(
            block,
            'LEFT',
            fallback: _defaultInput(base, 'left', fallback: '1'),
          ),
        );
        nextInputs['right'] = BlockInputModel(
          value: _fieldText(
            block,
            'RIGHT',
            fallback: _defaultInput(base, 'right', fallback: '1'),
          ),
        );
        break;
      case 'logic_and':
      case 'logic_or':
        nextInputs['left'] = _parseBooleanInput(
          block,
          'LEFT',
          fallback: _defaultBool(base, 'left', fallback: true),
        );
        nextInputs['right'] = _parseBooleanInput(
          block,
          'RIGHT',
          fallback: _defaultBool(base, 'right', fallback: true),
        );
        break;
      case 'logic_not':
        nextInputs['value'] = _parseBooleanInput(
          block,
          'VALUE',
          fallback: _defaultBool(base, 'value', fallback: true),
        );
        break;
      case 'bool_true':
      case 'bool_false':
        break;
      case 'string_is_empty':
      case 'string_not_empty':
        nextInputs['value'] = BlockInputModel(
          value: _fieldText(
            block,
            'VALUE',
            fallback: _defaultInput(base, 'value', fallback: ''),
          ),
        );
        break;
      default:
        break;
    }

    return base.copyWith(inputs: nextInputs, slots: nextSlots);
  }

  static Map<String, dynamic> _booleanInputNode(
    BlockInputModel? input, {
    required bool fallback,
  }) {
    final nested = input?.block;
    if (nested != null && _valueTypes.contains(nested.type)) {
      return {'block': _blockToJson(nested)};
    }

    final value = _toBool(input?.value, fallback: fallback);
    return {
      'shadow': {'type': value ? 'bool_true' : 'bool_false'},
    };
  }

  static BlockInputModel _parseBooleanInput(
    Map<String, dynamic> block,
    String inputName, {
    required bool fallback,
  }) {
    final nested = _parseValueInput(block, inputName);
    if (nested == null) {
      return BlockInputModel(value: fallback);
    }
    if (nested.type == 'bool_true') {
      return const BlockInputModel(value: true);
    }
    if (nested.type == 'bool_false') {
      return const BlockInputModel(value: false);
    }
    return BlockInputModel(block: nested);
  }

  static BlockModel? _parseValueInput(
    Map<String, dynamic> block,
    String inputName,
  ) {
    final nested = _inputBlock(block, inputName);
    if (nested == null) {
      return null;
    }
    final parsed = _parseBlock(nested);
    if (parsed == null || !_valueTypes.contains(parsed.type)) {
      return null;
    }
    return parsed;
  }

  static Map<String, dynamic>? _inputBlock(
    Map<String, dynamic> block,
    String inputName,
  ) {
    final inputs = _asMap(block['inputs']);
    final node = _asMap(inputs?[inputName]);
    return _asMap(node?['block']) ?? _asMap(node?['shadow']);
  }

  static Map<String, dynamic>? _nextBlock(Map<String, dynamic> block) {
    final next = _asMap(block['next']);
    return _asMap(next?['block']);
  }

  static String _stringInput(
    BlockModel block,
    String key, {
    required String fallback,
  }) {
    final value = block.inputs[key]?.value;
    if (value == null) {
      return fallback;
    }
    return value.toString();
  }

  static bool _boolInput(
    BlockModel block,
    String key, {
    required bool fallback,
  }) {
    final value = block.inputs[key]?.value;
    return _toBool(value, fallback: fallback);
  }

  static String _fieldText(
    Map<String, dynamic> block,
    String key, {
    required String fallback,
  }) {
    final fields = _asMap(block['fields']);
    final value = fields?[key];
    if (value == null) {
      return fallback;
    }
    return value.toString();
  }

  static String _blockId(Map<String, dynamic> block, String type) {
    final id = block['id']?.toString();
    if (id != null && id.trim().isNotEmpty) {
      return id;
    }
    return BlockRegistry.create(type).id;
  }

  static String _defaultInput(
    BlockModel block,
    String key, {
    required String fallback,
  }) {
    final value = block.inputs[key]?.value;
    if (value == null) {
      return fallback;
    }
    return value.toString();
  }

  static bool _defaultBool(
    BlockModel block,
    String key, {
    required bool fallback,
  }) {
    return _toBool(block.inputs[key]?.value, fallback: fallback);
  }

  static bool _toBool(dynamic raw, {required bool fallback}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final value = raw.trim().toLowerCase();
      if (value == 'true' || value == '1') return true;
      if (value == 'false' || value == '0') return false;
      if (value.isEmpty) return fallback;
      return true;
    }
    return fallback;
  }

  static double _numFrom(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw) ?? 0;
    }
    return 0;
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }
}

extension _FirstOrNullExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

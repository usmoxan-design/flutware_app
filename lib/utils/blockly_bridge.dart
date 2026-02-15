import 'dart:convert';
import '../models/app_models.dart';
import '../models/blocks.dart';

class BlocklyBridge {
  static bool isStatementType(String type) =>
      BlockDefinitions.isStatementType(type);
  static bool isValueType(String type) => BlockDefinitions.isValueType(type);

  static Set<String> get _supportedTypes => BlockDefinitions.supportedTypes;

  static Map<String, dynamic> toolboxJson() => BlockDefinitions.toolboxJson();

  static String buildCustomScript({
    required List<String> widgetIds,
    required List<PageData> pages,
  }) {
    final defaultWidgetId = (widgetIds.isEmpty ? 'button1' : widgetIds.first)
        .trim();
    final defaultPageId = (pages.isEmpty ? '' : pages.first.id).trim();
    final blocksJson = jsonEncode(
      BlockDefinitions.customBlockJsonArray(
        defaultWidgetId: defaultWidgetId.isEmpty ? 'button1' : defaultWidgetId,
        defaultPageId: defaultPageId,
      ),
    );
    final statementTypesJson = jsonEncode(
      BlockDefinitions.statementTypes.toList(),
    );
    final valueTypesJson = jsonEncode(BlockDefinitions.valueTypes.toList());

    return '''
<script>
(() => {
  if (typeof Blockly === 'undefined') return;

  // Define Modern Theme in JS
  const modernTheme = Blockly.Theme.defineTheme('modern', {
    'base': Blockly.Themes.Classic,
    'categoryStyles': {
      'variable_category': { 'colour': '#FF8A65' },
      'control_category': { 'colour': '#F4B400' },
      'operator_category': { 'colour': '#2E7D32' },
      'view_category': { 'colour': '#1E88E5' },
    },
    'blockStyles': {
      'variable_blocks': { 'colourPrimary': '#FF8A65' },
      'control_blocks': { 'colourPrimary': '#F4B400' },
      'operator_blocks': { 'colourPrimary': '#2E7D32' },
      'view_blocks': { 'colourPrimary': '#1E88E5' },
    },
    'componentStyles': {
      'workspaceBackgroundColour': '#F5F7FA',
      'toolboxBackgroundColour': '#FFFFFF',
      'toolboxForegroundColour': '#3C4043',
      'flyoutBackgroundColour': '#FFFFFF',
      'flyoutForegroundColour': '#3C4043',
      'scrollbarColour': '#D1D5DB',
      'insertionMarkerColour': '#000000',
      'insertionMarkerOpacity': 0.1,
    }
  });

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

  // Clean Premium Sidebar CSS
  const style = document.createElement('style');
  style.textContent = `
    .blocklyToolboxDiv {
      background-color: rgba(255, 255, 255, 0.98) !important;
      backdrop-filter: blur(10px);
      border-right: 1px solid #E0E4E9 !important;
      padding-top: 50px !important;
      width: 120px !important;
      transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
      z-index: 100 !important;
    }
    .blocklyToolboxDiv.collapsed {
      transform: translateX(-120px) !important;
    }
    .blocklyTreeLabel {
      font-family: 'Inter', sans-serif !important;
      font-size: 13px !important;
      font-weight: 500 !important;
      color: #3C4043 !important;
      padding: 8px 12px !important;
    }
    .blocklyTreeRow {
      height: 48px !important;
      margin: 4px 8px !important;
      border-radius: 12px !important;
      line-height: 48px !important;
      transition: all 0.2s ease !important;
    }
    /* Toggle Button Styling */
    #toolbox-toggle {
      position: fixed;
      left: 12px;
      top: 12px;
      width: 36px;
      height: 36px;
      background: white;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      z-index: 1001;
      cursor: pointer;
      transition: all 0.3s ease;
    }
    #toolbox-toggle svg { width: 20px; height: 20px; fill: #5F6368; }
    
    .blocklyTreeRow.blocklyTreeSelected {
      background-color: rgba(0, 0, 0, 0.05) !important;
    }
    .blocklyTreeIcon {
      display: none !important;
    }
    .blocklyFlyout {
      transition: transform 0.3s ease !important;
    }
    .blocklyFlyoutBackground {
      fill: #FFFFFF !important;
      fill-opacity: 0.95 !important;
    }

    .blocklyScrollbarHandle {
      fill: #D1D5DB !important;
      fill-opacity: 0.6 !important;
      rx: 4px !important;
    }
    .blocklyMainBackground {
      stroke: none !important;
    }
  `;
  document.head.appendChild(style);

  // Create Toggle Button
  const toggle = document.createElement('div');
  toggle.id = 'toolbox-toggle';
  toggle.innerHTML = '<svg viewBox="0 0 24 24"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/></svg>';
  document.body.appendChild(toggle);

  toggle.onclick = () => {
    const toolbox = document.querySelector('.blocklyToolboxDiv');
    if (toolbox) {
      toolbox.classList.toggle('collapsed');
      const isCollapsed = toolbox.classList.contains('collapsed');
      toggle.style.left = isCollapsed ? '12px' : '132px';
      toggle.innerHTML = isCollapsed 
        ? '<svg viewBox="0 0 24 24"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/></svg>'
        : '<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>';
      
      // Hide flyout when collapsed
      if (isCollapsed) {
        const workspace = Blockly.getMainWorkspace();
        if (workspace && workspace.getToolbox()) {
          workspace.getToolbox().clearSelection();
        }
      }
    }
  };

  // Apply Theme to Workspace
  const applyTheme = () => {
    const workspace = Blockly.getMainWorkspace();
    if (workspace) {
      workspace.setTheme(modernTheme);
      // Initial State: Collapsed
      const toolbox = document.querySelector('.blocklyToolboxDiv');
      if (toolbox) toolbox.classList.add('collapsed');

      // Auto-close on drag from toolbox
      workspace.addChangeListener((e) => {
        if (e.type === Blockly.Events.BLOCK_CREATE && !e.isForeign) {
          const toolbox = document.querySelector('.blocklyToolboxDiv');
          if (toolbox && !toolbox.classList.contains('collapsed')) {
            if (typeof toggle !== 'undefined') toggle.click();
          }
        }
      });

      clearInterval(themeInterval);
    }
  };
  const themeInterval = setInterval(applyTheme, 100);
  setTimeout(() => clearInterval(themeInterval), 5000);
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

  static Map<String, dynamic>? _statementListToChain(List<BlockModel> blocks) {
    final statements = blocks
        .where((item) => _supportedTypes.contains(item.type))
        .where((item) => isStatementType(item.type))
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
      case 'event_hat':
        out['fields'] = {
          'NAME': _stringInput(block, 'name', fallback: 'Harakat'),
        };
        break;

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
        if (condition != null && isValueType(condition.type)) {
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
      if (parsed != null && isStatementType(parsed.type)) {
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

    final base = BlockDefinitions.createBlock(type, id: _blockId(block, type));
    final nextInputs = <String, BlockInputModel>{...base.inputs};
    final nextSlots = <String, List<BlockModel>>{
      for (final entry in base.slots.entries) entry.key: [...entry.value],
    };

    switch (type) {
      case 'event_hat':
        nextInputs['name'] = BlockInputModel(
          value: _fieldText(
            block,
            'NAME',
            fallback: _defaultInput(base, 'name', fallback: 'Harakat'),
          ),
        );
        break;

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
    if (nested != null && isValueType(nested.type)) {
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
    if (parsed == null || !isValueType(parsed.type)) {
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

  static String _blockId(Map<String, dynamic> block, String type) {
    final id = block['id']?.toString();
    if (id != null && id.trim().isNotEmpty) {
      return id;
    }
    return '${type}_${DateTime.now().microsecondsSinceEpoch}';
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

  static bool _boolInput(
    BlockModel block,
    String key, {
    required bool fallback,
  }) {
    final value = block.inputs[key]?.value;
    return _toBool(value, fallback: fallback);
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

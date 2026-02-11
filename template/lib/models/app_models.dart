import 'dart:convert';

enum BlockCategory {
  variable,
  control,
  operator,
  view;

  String get label => switch (this) {
    BlockCategory.variable => 'Variable',
    BlockCategory.control => 'Control',
    BlockCategory.operator => 'Operator',
    BlockCategory.view => 'View',
  };
}

BlockCategory blockCategoryFromString(String raw) {
  for (final category in BlockCategory.values) {
    if (category.name == raw) {
      return category;
    }
  }
  return _inferCategoryForLegacyType(raw);
}

class BlockInputModel {
  final dynamic value;
  final BlockModel? block;

  const BlockInputModel({this.value, this.block});

  BlockInputModel copyWith({
    Object? value = _noValue,
    Object? block = _noValue,
  }) {
    return BlockInputModel(
      value: identical(value, _noValue) ? this.value : value,
      block: identical(block, _noValue) ? this.block : block as BlockModel?,
    );
  }

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    if (value != null) {
      out['value'] = value;
    }
    if (block != null) {
      out['block'] = block!.toJson();
    }
    return out;
  }

  factory BlockInputModel.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return BlockInputModel(
        value: json.containsKey('value') ? json['value'] : null,
        block: json['block'] is Map<String, dynamic>
            ? BlockModel.fromJson(json['block'] as Map<String, dynamic>)
            : null,
      );
    }
    return BlockInputModel(value: json);
  }
}

class BlockModel {
  final String id;
  final String type;
  final BlockCategory category;
  final Map<String, BlockInputModel> inputs;
  final Map<String, List<BlockModel>> slots;
  final BlockModel? next;

  const BlockModel({
    required this.id,
    required this.type,
    required this.category,
    this.inputs = const {},
    this.slots = const {},
    this.next,
  });

  BlockModel copyWith({
    String? id,
    String? type,
    BlockCategory? category,
    Map<String, BlockInputModel>? inputs,
    Map<String, List<BlockModel>>? slots,
    Object? next = _noValue,
  }) {
    return BlockModel(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      inputs: inputs ?? this.inputs,
      slots: slots ?? this.slots,
      next: identical(next, _noValue) ? this.next : next as BlockModel?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'category': category.name,
      'inputs': inputs.map((key, value) => MapEntry(key, value.toJson())),
      'slots': slots.map(
        (key, value) =>
            MapEntry(key, value.map((item) => item.toJson()).toList()),
      ),
      if (next != null) 'next': next!.toJson(),
    };
  }

  factory BlockModel.fromJson(Map<String, dynamic> json) {
    final rawInputs = json['inputs'];
    final inputMap = <String, BlockInputModel>{};
    if (rawInputs is Map) {
      rawInputs.forEach((key, value) {
        inputMap[key.toString()] = BlockInputModel.fromJson(value);
      });
    }

    final rawSlots = json['slots'];
    final slotMap = <String, List<BlockModel>>{};
    if (rawSlots is Map) {
      rawSlots.forEach((key, value) {
        final list = <BlockModel>[];
        if (value is List) {
          for (final item in value) {
            if (item is Map<String, dynamic>) {
              list.add(BlockModel.fromJson(item));
            } else if (item is Map) {
              list.add(BlockModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
        slotMap[key.toString()] = list;
      });
    }

    final rawType = json['type']?.toString() ?? 'unknown';
    final rawCategory = json['category']?.toString();

    BlockModel? next;
    final rawNext = json['next'];
    if (rawNext is Map<String, dynamic>) {
      next = BlockModel.fromJson(rawNext);
    } else if (rawNext is Map) {
      next = BlockModel.fromJson(Map<String, dynamic>.from(rawNext));
    }

    return BlockModel(
      id:
          json['id']?.toString() ??
          'block_${DateTime.now().microsecondsSinceEpoch}',
      type: rawType,
      category: rawCategory == null
          ? _inferCategoryForLegacyType(rawType)
          : blockCategoryFromString(rawCategory),
      inputs: inputMap,
      slots: slotMap,
      next: next,
    );
  }

  factory BlockModel.fromActionBlock(ActionBlock action) {
    final mappedType = switch (action.type) {
      'navigate' => 'navigate_push',
      'back' => 'navigate_pop',
      'equals' => 'compare_eq',
      _ => action.type,
    };

    final mappedInputs = <String, BlockInputModel>{};
    action.data.forEach((key, value) {
      if (key == 'condition' &&
          (action.type == 'if' || action.type == 'if_else')) {
        return;
      }
      if (key == 'targetPageId' && action.type == 'navigate') {
        mappedInputs['targetPage'] = BlockInputModel(value: value);
        return;
      }
      mappedInputs[key] = BlockInputModel(value: value);
    });

    final slotMap = <String, List<BlockModel>>{};
    if (action.type == 'if' || action.type == 'if_else') {
      slotMap['then'] = action.innerActions
          .map(BlockModel.fromActionBlock)
          .toList();
      if (action.type == 'if_else') {
        slotMap['else'] = action.elseActions
            .map(BlockModel.fromActionBlock)
            .toList();
      }
      final rawCondition = action.data['condition']?.toString().trim();
      if (rawCondition == null || rawCondition.isEmpty) {
        slotMap['condition'] = [
          BlockModel(
            id: 'block_${DateTime.now().microsecondsSinceEpoch}',
            type: 'bool_true',
            category: BlockCategory.operator,
          ),
        ];
      } else {
        final conditionType = rawCondition.toLowerCase() == 'false'
            ? 'bool_false'
            : rawCondition.toLowerCase() == 'true'
            ? 'bool_true'
            : null;
        if (conditionType != null) {
          slotMap['condition'] = [
            BlockModel(
              id: 'block_${DateTime.now().microsecondsSinceEpoch}',
              type: conditionType,
              category: BlockCategory.operator,
            ),
          ];
        } else {
          mappedInputs['condition'] = BlockInputModel(value: rawCondition);
        }
      }
    }

    return BlockModel(
      id: 'block_${DateTime.now().microsecondsSinceEpoch}',
      type: mappedType,
      category: _inferCategoryForLegacyType(mappedType),
      inputs: mappedInputs,
      slots: slotMap,
    );
  }

  ActionBlock toActionBlock() {
    final data = <String, dynamic>{};
    for (final entry in inputs.entries) {
      final input = entry.value;
      if (input.block != null) {
        data[entry.key] = input.block!._asLegacyConditionExpression();
      } else {
        data[entry.key] = input.value;
      }
    }

    if (type == 'if' || type == 'if_else') {
      final conditionBlock = slots['condition'];
      if ((conditionBlock ?? const []).isNotEmpty) {
        data['condition'] = conditionBlock!.first
            ._asLegacyConditionExpression();
      } else {
        data['condition'] = data['condition']?.toString() ?? 'true';
      }
    }

    final innerActions = (slots['then'] ?? const [])
        .map((item) => item.toActionBlock())
        .toList();
    final elseActions = (slots['else'] ?? const [])
        .map((item) => item.toActionBlock())
        .toList();

    final legacyType = switch (type) {
      'navigate_push' => 'navigate',
      'navigate_pop' => 'back',
      'compare_eq' => 'equals',
      _ => type,
    };

    if (legacyType == 'navigate' && data.containsKey('targetPage')) {
      data['targetPageId'] = data.remove('targetPage');
    }

    return ActionBlock(
      type: legacyType,
      data: data,
      innerActions: innerActions,
      elseActions: elseActions,
    );
  }

  String _asLegacyConditionExpression() {
    switch (type) {
      case 'bool_true':
        return 'true';
      case 'bool_false':
        return 'false';
      case 'compare_eq':
        return '${_legacyInput('left')} == ${_legacyInput('right')}';
      case 'compare_ne':
        return '${_legacyInput('left')} != ${_legacyInput('right')}';
      case 'compare_lt':
        return '${_legacyInput('left')} < ${_legacyInput('right')}';
      case 'compare_lte':
        return '${_legacyInput('left')} <= ${_legacyInput('right')}';
      case 'compare_gt':
        return '${_legacyInput('left')} > ${_legacyInput('right')}';
      case 'compare_gte':
        return '${_legacyInput('left')} >= ${_legacyInput('right')}';
      case 'logic_and':
        return '(${_legacyInput('left')}) && (${_legacyInput('right')})';
      case 'logic_or':
        return '(${_legacyInput('left')}) || (${_legacyInput('right')})';
      case 'logic_not':
        return '!(${_legacyInput('value')})';
      case 'string_is_empty':
        return '${_legacyInput('value')}.isEmpty';
      case 'string_not_empty':
        return '${_legacyInput('value')}.isNotEmpty';
      default:
        return inputs['condition']?.value?.toString() ?? 'true';
    }
  }

  String _legacyInput(String key) {
    final input = inputs[key];
    if (input == null) return 'true';
    if (input.block != null) {
      return input.block!._asLegacyConditionExpression();
    }
    return input.value?.toString() ?? 'true';
  }
}

class WidgetEventSchema {
  final List<BlockModel> onPressed;
  final List<BlockModel> onLongPress;
  final List<BlockModel> onChanged;

  const WidgetEventSchema({
    this.onPressed = const [],
    this.onLongPress = const [],
    this.onChanged = const [],
  });

  bool get isEmpty =>
      onPressed.isEmpty && onLongPress.isEmpty && onChanged.isEmpty;

  WidgetEventSchema copyWith({
    List<BlockModel>? onPressed,
    List<BlockModel>? onLongPress,
    List<BlockModel>? onChanged,
  }) {
    return WidgetEventSchema(
      onPressed: onPressed ?? this.onPressed,
      onLongPress: onLongPress ?? this.onLongPress,
      onChanged: onChanged ?? this.onChanged,
    );
  }

  WidgetEventSchema withEvent(String eventName, List<BlockModel> blocks) {
    switch (eventName) {
      case 'onPressed':
      case 'onClicked':
        return copyWith(onPressed: blocks);
      case 'onLongPress':
      case 'onLongPressed':
        return copyWith(onLongPress: blocks);
      case 'onChanged':
        return copyWith(onChanged: blocks);
      default:
        return this;
    }
  }

  List<BlockModel> eventBlocks(String eventName) {
    switch (eventName) {
      case 'onPressed':
      case 'onClicked':
        return onPressed;
      case 'onLongPress':
      case 'onLongPressed':
        return onLongPress;
      case 'onChanged':
        return onChanged;
      default:
        return const [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'onPressed': onPressed.map((item) => item.toJson()).toList(),
      'onLongPress': onLongPress.map((item) => item.toJson()).toList(),
      'onChanged': onChanged.map((item) => item.toJson()).toList(),
    };
  }

  factory WidgetEventSchema.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WidgetEventSchema();
    }

    List<BlockModel> parse(dynamic raw) {
      if (raw is! List) return const [];
      final out = <BlockModel>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          out.add(BlockModel.fromJson(item));
        } else if (item is Map) {
          out.add(BlockModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return out;
    }

    return WidgetEventSchema(
      onPressed: parse(json['onPressed'] ?? json['onClicked']),
      onLongPress: parse(json['onLongPress'] ?? json['onLongPressed']),
      onChanged: parse(json['onChanged']),
    );
  }

  factory WidgetEventSchema.fromLegacy(WidgetLogic logic) {
    return WidgetEventSchema(
      onPressed: logic.onPressed.map(BlockModel.fromActionBlock).toList(),
      onLongPress: logic.onLongPress.map(BlockModel.fromActionBlock).toList(),
    );
  }

  WidgetLogic toLegacy() {
    return WidgetLogic(
      onPressed: onPressed.map((item) => item.toActionBlock()).toList(),
      onLongPress: onLongPress.map((item) => item.toActionBlock()).toList(),
    );
  }
}

class EventSchema {
  final List<BlockModel> screenOnCreate;
  final Map<String, WidgetEventSchema> widgets;

  const EventSchema({this.screenOnCreate = const [], this.widgets = const {}});

  EventSchema copyWith({
    List<BlockModel>? screenOnCreate,
    Map<String, WidgetEventSchema>? widgets,
  }) {
    return EventSchema(
      screenOnCreate: screenOnCreate ?? this.screenOnCreate,
      widgets: widgets ?? this.widgets,
    );
  }

  EventSchema withOnCreate(List<BlockModel> blocks) {
    return copyWith(screenOnCreate: blocks);
  }

  EventSchema withWidgetEvent(
    String widgetId,
    String eventName,
    List<BlockModel> blocks,
  ) {
    final nextWidgets = <String, WidgetEventSchema>{...widgets};
    final existing = nextWidgets[widgetId] ?? const WidgetEventSchema();
    final updated = existing.withEvent(eventName, blocks);
    if (updated.isEmpty) {
      nextWidgets.remove(widgetId);
    } else {
      nextWidgets[widgetId] = updated;
    }
    return copyWith(widgets: nextWidgets);
  }

  EventSchema removeWidget(String widgetId) {
    if (!widgets.containsKey(widgetId)) return this;
    final nextWidgets = <String, WidgetEventSchema>{...widgets}
      ..remove(widgetId);
    return copyWith(widgets: nextWidgets);
  }

  List<BlockModel> widgetEventBlocks(String widgetId, String eventName) {
    return widgets[widgetId]?.eventBlocks(eventName) ?? const [];
  }

  Map<String, dynamic> toJson() {
    return {
      'screen': {
        'onCreate': screenOnCreate.map((item) => item.toJson()).toList(),
      },
      'widgets': widgets.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory EventSchema.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EventSchema();
    }

    final rawScreen = json['screen'];
    final rawOnCreate = rawScreen is Map ? rawScreen['onCreate'] : null;

    final onCreate = <BlockModel>[];
    if (rawOnCreate is List) {
      for (final item in rawOnCreate) {
        if (item is Map<String, dynamic>) {
          onCreate.add(BlockModel.fromJson(item));
        } else if (item is Map) {
          onCreate.add(BlockModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final widgets = <String, WidgetEventSchema>{};
    final rawWidgets = json['widgets'];
    if (rawWidgets is Map) {
      rawWidgets.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          widgets[key.toString()] = WidgetEventSchema.fromJson(value);
        } else if (value is Map) {
          widgets[key.toString()] = WidgetEventSchema.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return EventSchema(screenOnCreate: onCreate, widgets: widgets);
  }

  factory EventSchema.fromLegacy({
    required List<ActionBlock> onCreate,
    required Map<String, WidgetLogic> logic,
  }) {
    final widgetMap = <String, WidgetEventSchema>{};
    logic.forEach((key, value) {
      final mapped = WidgetEventSchema.fromLegacy(value);
      if (!mapped.isEmpty) {
        widgetMap[key] = mapped;
      }
    });

    return EventSchema(
      screenOnCreate: onCreate.map(BlockModel.fromActionBlock).toList(),
      widgets: widgetMap,
    );
  }

  List<ActionBlock> toLegacyOnCreate() {
    return screenOnCreate.map((item) => item.toActionBlock()).toList();
  }

  Map<String, WidgetLogic> toLegacyWidgetLogic() {
    final out = <String, WidgetLogic>{};
    widgets.forEach((key, value) {
      final mapped = value.toLegacy();
      if (mapped.onPressed.isNotEmpty || mapped.onLongPress.isNotEmpty) {
        out[key] = mapped;
      }
    });
    return out;
  }
}

/// Represents a simple action block (legacy compatibility)
class ActionBlock {
  final String type;
  final Map<String, dynamic> data;
  final List<ActionBlock> innerActions;
  final List<ActionBlock> elseActions;

  ActionBlock({
    required this.type,
    required this.data,
    this.innerActions = const [],
    this.elseActions = const [],
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'innerActions': innerActions.map((e) => e.toJson()).toList(),
    'elseActions': elseActions.map((e) => e.toJson()).toList(),
    ...data,
  };

  factory ActionBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final inner = (json['innerActions'] as List? ?? [])
        .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
        .toList();
    final elses = (json['elseActions'] as List? ?? [])
        .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
        .toList();
    final data = Map<String, dynamic>.from(json)
      ..remove('type')
      ..remove('innerActions')
      ..remove('elseActions');
    return ActionBlock(
      type: type,
      data: data,
      innerActions: inner,
      elseActions: elses,
    );
  }

  static ActionBlock toast(String message) =>
      ActionBlock(type: 'toast', data: {'message': message});

  static ActionBlock snackbar(String message) =>
      ActionBlock(type: 'snackbar', data: {'message': message});

  static ActionBlock navigate(String pageId) =>
      ActionBlock(type: 'navigate', data: {'targetPageId': pageId});
}

/// Legacy widget event model (kept for backward compatibility)
class WidgetLogic {
  final List<ActionBlock> onPressed;
  final List<ActionBlock> onLongPress;

  WidgetLogic({
    List<ActionBlock> onPressed = const [],
    List<ActionBlock> onLongPress = const [],
    List<ActionBlock>? onClicked,
    List<ActionBlock>? onLongPressed,
  }) : onPressed = onClicked ?? onPressed,
       onLongPress = onLongPressed ?? onLongPress;

  List<ActionBlock> get onClicked => onPressed;
  List<ActionBlock> get onLongPressed => onLongPress;

  Map<String, dynamic> toJson() => {
    'onPressed': onPressed.map((e) => e.toJson()).toList(),
    'onLongPress': onLongPress.map((e) => e.toJson()).toList(),
    'onClicked': onPressed.map((e) => e.toJson()).toList(),
    'onLongPressed': onLongPress.map((e) => e.toJson()).toList(),
  };

  factory WidgetLogic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WidgetLogic();

    List<ActionBlock> parse(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final pressed = parse(json['onPressed'] ?? json['onClicked']);
    final longPress = parse(json['onLongPress'] ?? json['onLongPressed']);

    return WidgetLogic(onPressed: pressed, onLongPress: longPress);
  }
}

class WidgetData {
  final String id;
  final String type;
  final Map<String, dynamic> properties;

  WidgetData({required this.id, required this.type, required this.properties});

  Map<String, dynamic> toJson() => {'id': id, 'type': type, ...properties};

  factory WidgetData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final type = json['type'] as String;
    final properties = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('type');
    return WidgetData(id: id, type: type, properties: properties);
  }

  String get text => properties['text'] ?? properties['label'] ?? '';
  double get fontSize => (properties['fontSize'] as num?)?.toDouble() ?? 16.0;
  bool get enabled => properties['enabled'] != false;
}

class PageData {
  final String id;
  final String name;
  final String type;
  final List<WidgetData> widgets;
  final EventSchema events;

  PageData({
    required this.id,
    required this.name,
    this.type = 'StatelessWidget',
    this.widgets = const [],
    Map<String, WidgetLogic> logic = const {},
    List<ActionBlock> onCreate = const [],
    EventSchema? events,
  }) : events =
           events ?? EventSchema.fromLegacy(onCreate: onCreate, logic: logic);

  List<ActionBlock> get onCreate => events.toLegacyOnCreate();
  Map<String, WidgetLogic> get logic => events.toLegacyWidgetLogic();

  Map<String, dynamic> toJson() {
    final legacyLogic = logic;
    return {
      'id': id,
      'name': name,
      'type': type,
      'widgets': widgets.map((e) => e.toJson()).toList(),
      'events': events.toJson(),
      'logic': {
        'onCreate': onCreate.map((e) => e.toJson()).toList(),
        ...legacyLogic.map((key, value) => MapEntry(key, value.toJson())),
      },
    };
  }

  factory PageData.fromJson(Map<String, dynamic> json) {
    final legacyLogicJson = json['logic'] as Map<String, dynamic>? ?? {};
    final legacyOnCreateJson = legacyLogicJson['onCreate'] as List? ?? [];

    final legacyLogicMap = <String, WidgetLogic>{};
    legacyLogicJson.forEach((key, value) {
      if (key == 'onCreate') return;
      if (value is Map<String, dynamic>) {
        legacyLogicMap[key] = WidgetLogic.fromJson(value);
      } else if (value is Map) {
        legacyLogicMap[key] = WidgetLogic.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    });

    final legacyOnCreate = legacyOnCreateJson
        .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
        .toList();

    EventSchema events;
    final rawEvents = json['events'];
    if (rawEvents is Map<String, dynamic>) {
      events = EventSchema.fromJson(rawEvents);
    } else if (rawEvents is Map) {
      events = EventSchema.fromJson(Map<String, dynamic>.from(rawEvents));
    } else {
      events = EventSchema.fromLegacy(
        onCreate: legacyOnCreate,
        logic: legacyLogicMap,
      );
    }

    return PageData(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'StatelessWidget',
      widgets: (json['widgets'] as List? ?? [])
          .map((e) => WidgetData.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: events,
    );
  }
}

class ProjectData {
  final String appName;
  final String packageName;
  final String versionCode;
  final String versionName;
  final bool useMaterial3;
  final String colorPrimary;
  final String colorPrimaryDark;
  final String colorAccent;
  final List<PageData> pages;

  ProjectData({
    required this.appName,
    this.packageName = 'com.example.myapp',
    this.versionCode = '1',
    this.versionName = '1.0',
    this.useMaterial3 = true,
    this.colorPrimary = '0xFF2196F3',
    this.colorPrimaryDark = '0xFF1976D2',
    this.colorAccent = '0xFFFF4081',
    this.pages = const [],
  });

  Map<String, dynamic> toJson() => {
    'appName': appName,
    'packageName': packageName,
    'versionCode': versionCode,
    'versionName': versionName,
    'useMaterial3': useMaterial3,
    'colorPrimary': colorPrimary,
    'colorPrimaryDark': colorPrimaryDark,
    'colorAccent': colorAccent,
    'pages': pages.map((e) => e.toJson()).toList(),
  };

  factory ProjectData.fromJson(Map<String, dynamic> json) {
    return ProjectData(
      appName: json['appName'] as String,
      packageName: json['packageName'] as String? ?? 'com.example.myapp',
      versionCode: json['versionCode'] as String? ?? '1',
      versionName: json['versionName'] as String? ?? '1.0',
      useMaterial3: json['useMaterial3'] as bool? ?? true,
      colorPrimary: json['colorPrimary'] as String? ?? '0xFF2196F3',
      colorPrimaryDark: json['colorPrimaryDark'] as String? ?? '0xFF1976D2',
      colorAccent: json['colorAccent'] as String? ?? '0xFFFF4081',
      pages: (json['pages'] as List? ?? [])
          .map((e) => PageData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  static ProjectData decode(String source) =>
      ProjectData.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

extension PageDataExt on PageData {
  PageData copyWith({
    String? name,
    List<WidgetData>? widgets,
    Map<String, WidgetLogic>? logic,
    List<ActionBlock>? onCreate,
    String? type,
    EventSchema? events,
  }) {
    final resolvedEvents =
        events ??
        ((logic != null || onCreate != null)
            ? EventSchema.fromLegacy(
                onCreate: onCreate ?? this.onCreate,
                logic: logic ?? this.logic,
              )
            : this.events);

    return PageData(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      widgets: widgets ?? this.widgets,
      events: resolvedEvents,
    );
  }
}

extension ProjectDataExt on ProjectData {
  ProjectData copyWith({
    String? appName,
    String? packageName,
    String? versionCode,
    String? versionName,
    bool? useMaterial3,
    String? colorPrimary,
    String? colorPrimaryDark,
    String? colorAccent,
    List<PageData>? pages,
  }) {
    return ProjectData(
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      versionCode: versionCode ?? this.versionCode,
      versionName: versionName ?? this.versionName,
      useMaterial3: useMaterial3 ?? this.useMaterial3,
      colorPrimary: colorPrimary ?? this.colorPrimary,
      colorPrimaryDark: colorPrimaryDark ?? this.colorPrimaryDark,
      colorAccent: colorAccent ?? this.colorAccent,
      pages: pages ?? this.pages,
    );
  }
}

BlockCategory _inferCategoryForLegacyType(String type) {
  switch (type) {
    case 'set_variable':
      return BlockCategory.variable;
    case 'if':
    case 'if_else':
      return BlockCategory.control;
    case 'equals':
    case 'compare_eq':
    case 'compare_ne':
    case 'compare_lt':
    case 'compare_lte':
    case 'compare_gt':
    case 'compare_gte':
    case 'logic_and':
    case 'logic_or':
    case 'logic_not':
    case 'bool_true':
    case 'bool_false':
    case 'string_is_empty':
    case 'string_not_empty':
      return BlockCategory.operator;
    default:
      return BlockCategory.view;
  }
}

const Object _noValue = Object();

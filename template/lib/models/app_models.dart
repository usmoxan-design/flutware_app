import 'dart:convert';

/// Represents a simple action block (e.g., Toast)
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

/// Represents the logic for a widget's events
class WidgetLogic {
  final List<ActionBlock> onClicked;
  final List<ActionBlock> onLongPressed;

  WidgetLogic({this.onClicked = const [], this.onLongPressed = const []});

  Map<String, dynamic> toJson() => {
    'onClicked': onClicked.map((e) => e.toJson()).toList(),
    'onLongPressed': onLongPressed.map((e) => e.toJson()).toList(),
  };

  factory WidgetLogic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WidgetLogic();
    return WidgetLogic(
      onClicked: (json['onClicked'] as List? ?? [])
          .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
      onLongPressed: (json['onLongPressed'] as List? ?? [])
          .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Represents a UI widget (Text or Button)
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

  // Helpers
  String get text => properties['text'] ?? properties['label'] ?? '';
  double get fontSize => (properties['fontSize'] as num?)?.toDouble() ?? 16.0;
}

/// Represents a single page in the project
class PageData {
  final String id;
  final String name;
  final String type; // StatelessWidget or StatefulWidget
  final List<WidgetData> widgets;
  final Map<String, WidgetLogic> logic; // widgetId -> logic
  final List<ActionBlock> onCreate;

  PageData({
    required this.id,
    required this.name,
    this.type = 'StatelessWidget',
    this.widgets = const [],
    this.logic = const {},
    this.onCreate = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'widgets': widgets.map((e) => e.toJson()).toList(),
    'logic': {
      'onCreate': onCreate.map((e) => e.toJson()).toList(),
      ...logic.map((key, value) => MapEntry(key, value.toJson())),
    },
  };

  factory PageData.fromJson(Map<String, dynamic> json) {
    final logicJson = json['logic'] as Map<String, dynamic>? ?? {};
    final onCreateJson = logicJson['onCreate'] as List? ?? [];

    final logicMap = <String, WidgetLogic>{};
    logicJson.forEach((key, value) {
      if (key != 'onCreate' && value is Map<String, dynamic>) {
        logicMap[key] = WidgetLogic.fromJson(value);
      }
    });

    return PageData(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'StatelessWidget',
      widgets: (json['widgets'] as List? ?? [])
          .map((e) => WidgetData.fromJson(e as Map<String, dynamic>))
          .toList(),
      logic: logicMap,
      onCreate: onCreateJson
          .map((e) => ActionBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Represents the whole project
class ProjectData {
  final String appName;
  final String packageName;
  final String versionCode;
  final String versionName;
  final String colorPrimary;
  final String colorPrimaryDark;
  final String colorAccent;
  final List<PageData> pages;

  ProjectData({
    required this.appName,
    this.packageName = 'com.example.myapp',
    this.versionCode = '1',
    this.versionName = '1.0',
    this.colorPrimary = '0xFF2196F3', // Blue
    this.colorPrimaryDark = '0xFF1976D2', // Dark Blue
    this.colorAccent = '0xFFFF4081', // Pink
    this.pages = const [],
  });

  Map<String, dynamic> toJson() => {
    'appName': appName,
    'packageName': packageName,
    'versionCode': versionCode,
    'versionName': versionName,
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
  }) {
    return PageData(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      widgets: widgets ?? this.widgets,
      logic: logic ?? this.logic,
      onCreate: onCreate ?? this.onCreate,
    );
  }
}

extension ProjectDataExt on ProjectData {
  ProjectData copyWith({
    String? appName,
    String? packageName,
    String? versionCode,
    String? versionName,
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
      colorPrimary: colorPrimary ?? this.colorPrimary,
      colorPrimaryDark: colorPrimaryDark ?? this.colorPrimaryDark,
      colorAccent: colorAccent ?? this.colorAccent,
      pages: pages ?? this.pages,
    );
  }
}

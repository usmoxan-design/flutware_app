import '../models/app_models.dart';

class DartCodeGenerator {
  static String generate(ProjectData project, PageData page) {
    return generatePageSource(
      project,
      page,
      includeMain: true,
      useNamedRoutes: false,
    );
  }

  static String generatePageSource(
    ProjectData project,
    PageData page, {
    required bool includeMain,
    required bool useNamedRoutes,
    String? classNameOverride,
    Map<String, String>? routeByPageId,
    Map<String, String>? classByPageId,
    Map<String, String>? fileByPageId,
  }) {
    final className = classNameOverride ?? '${_toPascal(page.name)}Page';
    final hasAnyLogic =
        page.onCreate.isNotEmpty ||
        page.logic.values.any(
          (logic) => logic.onPressed.isNotEmpty || logic.onLongPress.isNotEmpty,
        );
    final isStateful = page.type == 'StatefulWidget' || hasAnyLogic;

    final usedBlockTypes = <String>{};
    final targetPageIds = <String>{};

    void collect(List<ActionBlock> actions) {
      for (final action in actions) {
        usedBlockTypes.add(action.type);
        if ((action.type == 'navigate' || action.type == 'navigate_push') &&
            action.data['targetPageId'] != null) {
          targetPageIds.add(action.data['targetPageId'].toString());
        }
        if (action.type == 'navigate_push' &&
            action.data['targetPage'] != null) {
          targetPageIds.add(action.data['targetPage'].toString());
        }
      }
    }

    collect(page.onCreate);
    for (final logic in page.logic.values) {
      collect(logic.onPressed);
      collect(logic.onLongPress);
    }

    final hasSetEnabled = usedBlockTypes.contains('set_enabled');
    final hasRequestFocus = usedBlockTypes.contains('request_focus');
    final buttonIds = _flattenWidgets(
      page.widgets,
    ).where((item) => item.type == 'button').map((item) => item.id).toList();

    final imports = <String>["import 'package:flutter/material.dart';"];
    if (usedBlockTypes.contains('toast')) {
      imports.add("import 'package:fluttertoast/fluttertoast.dart';");
    }

    if (!useNamedRoutes) {
      for (final id in targetPageIds) {
        final targetPage = project.pages.firstWhere(
          (p) => p.id == id,
          orElse: () => PageData(id: '', name: 'unknown'),
        );
        if (targetPage.id.isNotEmpty) {
          final fileName =
              fileByPageId?[targetPage.id] ??
              '${_toSnake(targetPage.name)}_page.dart';
          imports.add("import '$fileName';");
        }
      }
    }

    final importStr = imports.toSet().join('\n');
    final appBarWidget = _rootWidgetByType(page.widgets, 'appbar');
    final fabWidget = _rootWidgetByType(page.widgets, 'fab');
    final bodyWidgets = page.widgets
        .where(
          (widget) =>
              (appBarWidget == null || widget.id != appBarWidget.id) &&
              (fabWidget == null || widget.id != fabWidget.id),
        )
        .toList();
    final bodyRoot = bodyWidgets.firstOrNull;

    final initStateCode = generateActionBlocksOnly(
      project,
      page.onCreate,
      indent: '      ',
      useNamedRoutes: useNamedRoutes,
      allowStateMutation: hasSetEnabled && isStateful,
      routeByPageId: routeByPageId,
      classByPageId: classByPageId,
    );

    final enabledMapField = hasSetEnabled && buttonIds.isNotEmpty
        ? '''
  final Map<String, bool> _enabledById = {
${buttonIds.map((id) {
            final widget = _findWidgetById(page.widgets, id);
            final enabled = widget?.enabled ?? true;
            return "    '${_escapeDartString(id)}': $enabled,";
          }).join('\n')}
  };
'''
        : '';

    final focusNodesField = hasRequestFocus
        ? '''
  final Map<String, FocusNode> _focusNodes = {};
'''
        : '';

    final disposeCode = hasRequestFocus
        ? '''
  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }
'''
        : '';

    final bodyCode = bodyRoot == null
        ? '      body: const SizedBox.shrink(),'
        : '      body:\n${_indentLines(_generateWidgetCode(project, bodyRoot, logicById: page.logic, indent: '', useNamedRoutes: useNamedRoutes, useEnabledStateMap: hasSetEnabled && isStateful, routeByPageId: routeByPageId, classByPageId: classByPageId, insideFlex: false), 8)},';

    final appBarCode = appBarWidget == null
        ? ''
        : '''
      appBar: AppBar(
        title: Text("${_escapeDartString(appBarWidget.properties['title']?.toString() ?? page.name)}"),
        backgroundColor: ${_colorLiteral(appBarWidget.properties['backgroundColor']?.toString(), project.colorPrimary)},
        foregroundColor: Colors.white,
      ),
''';

    final fabCode = fabWidget == null
        ? ''
        : '''
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: ${_colorLiteral(project.colorAccent, project.colorAccent)},
        child: const Icon(Icons.add),
      ),
''';

    final classCode = isStateful
        ? '''
class $className extends StatefulWidget {
  const $className({super.key});

  @override
  State<$className> createState() => _${className}State();
}

class _${className}State extends State<$className> {
$enabledMapField$focusNodesField
  @override
  void initState() {
    super.initState();
${initStateCode.isEmpty ? '    // Sahifa yuklanganda bajariladigan kodlar' : '    WidgetsBinding.instance.addPostFrameCallback((_) {\n      if (!mounted) return;\n$initStateCode\n    });'}
  }

$disposeCode
  @override
  Widget build(BuildContext context) {
    return Scaffold(
$appBarCode$fabCode
$bodyCode
    );
  }
}
'''
        : '''
class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
$appBarCode$fabCode
$bodyCode
    );
  }
}
''';

    if (!includeMain) {
      return '$importStr\n\n$classCode';
    }

    return '''
$importStr

void main() => runApp(const MaterialApp(home: $className()));

$classCode
''';
  }

  static Map<String, String> generateFlutterProjectFiles(ProjectData project) {
    final pages = project.pages.isEmpty
        ? [PageData(id: 'home', name: 'Home', type: 'StatelessWidget')]
        : project.pages;

    final pageSpecs = _buildPageSpecs(pages);
    final routeByPageId = <String, String>{
      for (final spec in pageSpecs) spec.page.id: spec.routeName,
    };
    final classByPageId = <String, String>{
      for (final spec in pageSpecs) spec.page.id: spec.className,
    };
    final fileByPageId = <String, String>{
      for (final spec in pageSpecs) spec.page.id: spec.fileName,
    };

    final hasToast = _projectUsesBlockType(pages, 'toast');
    final files = <String, String>{};

    files['pubspec.yaml'] = _generatePubspec(project, hasToast: hasToast);
    files['analysis_options.yaml'] = '''
include: package:flutter_lints/flutter.yaml
''';
    files['README.md'] =
        '''
# ${project.appName}

Generated by Flutware.

## Run

1. Install Flutter SDK.
2. Open this folder in Android Studio.
3. Run `flutter pub get`.
4. If platform folders are missing, run `flutter create .`.
5. Run on device/emulator.
''';

    files['lib/main.dart'] = _generateProjectMainFile(project, pageSpecs);

    for (final spec in pageSpecs) {
      files['lib/pages/${spec.fileName}'] = generatePageSource(
        project,
        spec.page,
        includeMain: false,
        useNamedRoutes: true,
        classNameOverride: spec.className,
        routeByPageId: routeByPageId,
        classByPageId: classByPageId,
        fileByPageId: fileByPageId,
      );
    }

    return files;
  }

  static String _generateWidgetCode(
    ProjectData project,
    WidgetData widget, {
    required Map<String, WidgetLogic> logicById,
    required String indent,
    required bool useNamedRoutes,
    required bool useEnabledStateMap,
    Map<String, String>? routeByPageId,
    Map<String, String>? classByPageId,
    required bool insideFlex,
  }) {
    final logic = logicById[widget.id];
    final onPressedCode = generateActionBlocksOnly(
      project,
      logic?.onPressed ?? [],
      indent: '$indent    ',
      useNamedRoutes: useNamedRoutes,
      allowStateMutation: useEnabledStateMap,
      routeByPageId: routeByPageId,
      classByPageId: classByPageId,
    );
    final onLongPressedCode = generateActionBlocksOnly(
      project,
      logic?.onLongPress ?? [],
      indent: '$indent    ',
      useNamedRoutes: useNamedRoutes,
      allowStateMutation: useEnabledStateMap,
      routeByPageId: routeByPageId,
      classByPageId: classByPageId,
    );

    final innerIndent = '$indent  ';
    final children = _childrenOf(widget);

    switch (widget.type) {
      case 'appbar':
      case 'fab':
        return '$indent const SizedBox.shrink()';
      case 'text':
        return '''
$indent Text(
$indent   "${_escapeDartString(widget.text)}",
$indent   style: const TextStyle(fontSize: ${widget.fontSize}),
$indent )''';
      case 'button':
        final enabledExpression = useEnabledStateMap
            ? "(_enabledById['${_escapeDartString(widget.id)}'] ?? ${widget.enabled})"
            : (widget.enabled ? 'true' : 'false');
        final backgroundColor = _colorLiteral(
          widget.properties['backgroundColor']?.toString(),
          project.colorPrimary,
        );
        final onPressedBody = onPressedCode.isEmpty
            ? '$indent      // Tugma bosilganda'
            : onPressedCode;
        final onLongPressedBody = onLongPressedCode.isEmpty
            ? '$indent      // Tugma bosib turilganda'
            : onLongPressedCode;
        return '''
$indent ElevatedButton(
$indent  onPressed: $enabledExpression ? () {
$onPressedBody
$indent  } : null,
$indent  onLongPress: $enabledExpression ? () {
$onLongPressedBody
$indent  } : null,
$indent  style: ElevatedButton.styleFrom(
$indent    backgroundColor: $backgroundColor,
$indent    foregroundColor: Colors.white,
$indent  ),
$indent  child: Text("${_escapeDartString(widget.text)}"),
$indent )''';
      case 'single_scroll':
        final axis =
            widget.properties['scrollDirection']?.toString() == 'horizontal'
            ? 'Axis.horizontal'
            : 'Axis.vertical';
        final physics = _scrollPhysicsExpression(
          widget.properties['physics']?.toString(),
        );
        final reverse = widget.properties['reverse'] == true ? 'true' : 'false';
        final padding =
            (widget.properties['padding'] as num?)?.toDouble() ?? 0.0;
        final childCode = children.isEmpty
            ? '$innerIndent const SizedBox.shrink()'
            : _generateWidgetCode(
                project,
                children.first,
                logicById: logicById,
                indent: innerIndent,
                useNamedRoutes: useNamedRoutes,
                useEnabledStateMap: useEnabledStateMap,
                routeByPageId: routeByPageId,
                classByPageId: classByPageId,
                insideFlex: false,
              );
        return '''
$indent SingleChildScrollView(
$indent  scrollDirection: $axis,
$indent  reverse: $reverse,
$indent  physics: $physics,
$indent  padding: EdgeInsets.all(${padding.toStringAsFixed(1)}),
$indent  child:
$childCode,
$indent )''';
      case 'padding':
        final padding =
            (widget.properties['padding'] as num?)?.toDouble() ?? 0.0;
        final childCode = children.isEmpty
            ? '$innerIndent const SizedBox.shrink()'
            : _generateWidgetCode(
                project,
                children.first,
                logicById: logicById,
                indent: innerIndent,
                useNamedRoutes: useNamedRoutes,
                useEnabledStateMap: useEnabledStateMap,
                routeByPageId: routeByPageId,
                classByPageId: classByPageId,
                insideFlex: false,
              );
        return '''
$indent Padding(
$indent  padding: EdgeInsets.all(${padding.toStringAsFixed(1)}),
$indent  child:
$childCode,
$indent )''';
      case 'expanded':
        final flex = (widget.properties['flex'] as num?)?.toInt() ?? 1;
        final childCode = children.isEmpty
            ? '$innerIndent const SizedBox.shrink()'
            : _generateWidgetCode(
                project,
                children.first,
                logicById: logicById,
                indent: innerIndent,
                useNamedRoutes: useNamedRoutes,
                useEnabledStateMap: useEnabledStateMap,
                routeByPageId: routeByPageId,
                classByPageId: classByPageId,
                insideFlex: false,
              );
        if (!insideFlex) {
          return childCode;
        }
        return '''
$indent Expanded(
$indent  flex: $flex,
$indent  child:
$childCode,
$indent )''';
      case 'row':
        final rowChildren = children.isEmpty
            ? '$innerIndent      const SizedBox.shrink(),'
            : children
                  .map(
                    (child) => _generateWidgetCode(
                      project,
                      child,
                      logicById: logicById,
                      indent: '$innerIndent      ',
                      useNamedRoutes: useNamedRoutes,
                      useEnabledStateMap: useEnabledStateMap,
                      routeByPageId: routeByPageId,
                      classByPageId: classByPageId,
                      insideFlex: true,
                    ),
                  )
                  .map((code) => '$code,')
                  .join('\n');
        return '''
$indent Row(
$indent  mainAxisAlignment: ${_mainAxisAlignmentExpression(widget.properties['mainAxisAlignment']?.toString())},
$indent  crossAxisAlignment: ${_crossAxisAlignmentExpression(widget.properties['crossAxisAlignment']?.toString())},
$indent  mainAxisSize: ${_mainAxisSizeExpression(widget.properties['mainAxisSize']?.toString())},
$indent  textDirection: ${_textDirectionExpression(widget.properties['textDirection']?.toString())},
$indent  verticalDirection: ${_verticalDirectionExpression(widget.properties['verticalDirection']?.toString())},
$indent  children: [
$rowChildren
$indent  ],
$indent )''';
      case 'column':
        final columnChildren = children.isEmpty
            ? '$innerIndent      const SizedBox.shrink(),'
            : children
                  .map(
                    (child) => _generateWidgetCode(
                      project,
                      child,
                      logicById: logicById,
                      indent: '$innerIndent      ',
                      useNamedRoutes: useNamedRoutes,
                      useEnabledStateMap: useEnabledStateMap,
                      routeByPageId: routeByPageId,
                      classByPageId: classByPageId,
                      insideFlex: true,
                    ),
                  )
                  .map((code) => '$code,')
                  .join('\n');
        return '''
$indent Column(
$indent  mainAxisAlignment: ${_mainAxisAlignmentExpression(widget.properties['mainAxisAlignment']?.toString())},
$indent  crossAxisAlignment: ${_crossAxisAlignmentExpression(widget.properties['crossAxisAlignment']?.toString())},
$indent  mainAxisSize: ${_mainAxisSizeExpression(widget.properties['mainAxisSize']?.toString())},
$indent  textDirection: ${_textDirectionExpression(widget.properties['textDirection']?.toString())},
$indent  verticalDirection: ${_verticalDirectionExpression(widget.properties['verticalDirection']?.toString())},
$indent  children: [
$columnChildren
$indent  ],
$indent )''';
      default:
        return '$indent const SizedBox(), // Noma\'lum widget: ${widget.type}';
    }
  }

  static List<WidgetData> _childrenOf(WidgetData widget) {
    final raw = widget.properties['children'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((entry) {
      return WidgetData.fromJson(Map<String, dynamic>.from(entry));
    }).toList();
  }

  static String generateActionBlocksOnly(
    ProjectData project,
    List<ActionBlock> actions, {
    String indent = '',
    bool useNamedRoutes = false,
    bool allowStateMutation = false,
    Map<String, String>? routeByPageId,
    Map<String, String>? classByPageId,
  }) {
    if (actions.isEmpty) return '';

    return actions
        .map((action) {
          switch (action.type) {
            case 'toast':
              return '$indent  Fluttertoast.showToast(msg: "${_escapeDartString(action.data['message']?.toString() ?? '')}");';
            case 'snackbar':
              return '''
$indent  ScaffoldMessenger.of(context).showSnackBar(
$indent    const SnackBar(
$indent      content: Text("${_escapeDartString(action.data['message']?.toString() ?? '')}"),
$indent      backgroundColor: Colors.green,
$indent      behavior: SnackBarBehavior.floating,
$indent    ),
$indent  );''';
            case 'navigate':
            case 'navigate_push':
              final targetPageId =
                  action.data['targetPageId']?.toString() ??
                  action.data['targetPage']?.toString();
              if (targetPageId == null || targetPageId.isEmpty) {
                return '$indent  // Navigate target topilmadi';
              }
              if (useNamedRoutes) {
                final routeName = routeByPageId?[targetPageId] ?? '/';
                return '$indent  Navigator.pushNamed(context, \'$routeName\');';
              }
              final targetPage = project.pages.firstWhere(
                (p) => p.id == targetPageId,
                orElse: () => PageData(id: '', name: 'Unknown'),
              );
              final targetClassName =
                  classByPageId?[targetPage.id] ??
                  '${_toPascal(targetPage.name)}Page';
              return '''
$indent  Navigator.push(
$indent    context,
$indent    MaterialPageRoute(builder: (context) => const $targetClassName()),
$indent  );''';
            case 'if':
              final condition = action.data['condition']?.toString() ?? 'true';
              final innerCode = generateActionBlocksOnly(
                project,
                action.innerActions,
                indent: '$indent  ',
                useNamedRoutes: useNamedRoutes,
                allowStateMutation: allowStateMutation,
                routeByPageId: routeByPageId,
                classByPageId: classByPageId,
              );
              return '''
$indent  if ($condition) {
${innerCode.isEmpty ? '$indent    // Bo\'sh' : innerCode}
$indent  }''';
            case 'if_else':
              final condition = action.data['condition']?.toString() ?? 'true';
              final innerCode = generateActionBlocksOnly(
                project,
                action.innerActions,
                indent: '$indent  ',
                useNamedRoutes: useNamedRoutes,
                allowStateMutation: allowStateMutation,
                routeByPageId: routeByPageId,
                classByPageId: classByPageId,
              );
              final elseCode = generateActionBlocksOnly(
                project,
                action.elseActions,
                indent: '$indent  ',
                useNamedRoutes: useNamedRoutes,
                allowStateMutation: allowStateMutation,
                routeByPageId: routeByPageId,
                classByPageId: classByPageId,
              );
              return '''
$indent  if ($condition) {
${innerCode.isEmpty ? '$indent    // Bo\'sh' : innerCode}
$indent  } else {
${elseCode.isEmpty ? '$indent    // Bo\'sh' : elseCode}
$indent  }''';
            case 'set_variable':
              final rawName = action.data['name']?.toString() ?? 'value';
              final safeName = rawName
                  .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
                  .replaceAll(RegExp(r'_+'), '_')
                  .replaceAll(RegExp(r'^\d'), '_\$0');
              return '$indent  final $safeName = ${action.data['value'] ?? 'null'};';
            case 'equals':
              return '$indent  final _isEqual = (${action.data['a'] ?? '0'}) == (${action.data['b'] ?? '0'});';
            case 'set_enabled':
              if (!allowStateMutation) {
                return '$indent  // setEnabled uchun Stateful context talab qilinadi';
              }
              final widgetId = _escapeDartString(
                action.data['widgetId']?.toString() ?? 'button1',
              );
              final enabledExpr = _asBoolExpression(action.data['enabled']);
              return '''
$indent  setState(() {
$indent    _enabledById['$widgetId'] = $enabledExpr;
$indent  });''';
            case 'request_focus':
              final widgetId = _escapeDartString(
                action.data['widgetId']?.toString() ?? 'button1',
              );
              return '''
$indent  FocusScope.of(context).requestFocus(
$indent    _focusNodes.putIfAbsent('$widgetId', () => FocusNode()),
$indent  );''';
            case 'get_width':
              return '$indent  final _width = MediaQuery.of(context).size.width; // ${action.data['widgetId'] ?? 'widget'}';
            case 'get_height':
              return '$indent  final _height = MediaQuery.of(context).size.height; // ${action.data['widgetId'] ?? 'widget'}';
            case 'navigate_pop':
            case 'back':
              return '$indent  Navigator.of(context).pop();';
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
              return '$indent  // Operator block (${action.type}) statement sifatida bajarilmaydi';
            default:
              return '$indent  // Action: ${action.type}';
          }
        })
        .join('\n');
  }

  static WidgetData? _rootWidgetByType(List<WidgetData> widgets, String type) {
    for (final widget in widgets) {
      if (widget.type == type) return widget;
    }
    return null;
  }

  static String _indentLines(String code, int spaces) {
    final prefix = ' ' * spaces;
    return code
        .split('\n')
        .map((line) {
          if (line.trim().isEmpty) return line;
          return '$prefix$line';
        })
        .join('\n');
  }

  static String _colorLiteral(String? value, String fallback) {
    final raw = value?.trim();
    if (raw != null && raw.startsWith('0x')) {
      return 'Color($raw)';
    }
    return 'Color($fallback)';
  }

  static String _mainAxisAlignmentExpression(String? raw) {
    return switch (raw) {
      'center' => 'MainAxisAlignment.center',
      'end' => 'MainAxisAlignment.end',
      'spaceBetween' => 'MainAxisAlignment.spaceBetween',
      'spaceAround' => 'MainAxisAlignment.spaceAround',
      'spaceEvenly' => 'MainAxisAlignment.spaceEvenly',
      _ => 'MainAxisAlignment.start',
    };
  }

  static String _crossAxisAlignmentExpression(String? raw) {
    return switch (raw) {
      'center' => 'CrossAxisAlignment.center',
      'end' => 'CrossAxisAlignment.end',
      'stretch' => 'CrossAxisAlignment.stretch',
      _ => 'CrossAxisAlignment.start',
    };
  }

  static String _mainAxisSizeExpression(String? raw) {
    return raw == 'max' ? 'MainAxisSize.max' : 'MainAxisSize.min';
  }

  static String _textDirectionExpression(String? raw) {
    return raw == 'rtl' ? 'TextDirection.rtl' : 'TextDirection.ltr';
  }

  static String _verticalDirectionExpression(String? raw) {
    return raw == 'up' ? 'VerticalDirection.up' : 'VerticalDirection.down';
  }

  static String _scrollPhysicsExpression(String? raw) {
    return switch (raw) {
      'bouncing' => 'const BouncingScrollPhysics()',
      'never' => 'const NeverScrollableScrollPhysics()',
      _ => 'const ClampingScrollPhysics()',
    };
  }

  static List<_PageSpec> _buildPageSpecs(List<PageData> pages) {
    final specs = <_PageSpec>[];
    final usedFiles = <String>{};
    final usedClasses = <String>{};
    final usedRoutes = <String>{};

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final fileBase = _toSnake(page.name).isEmpty
          ? 'page_$i'
          : _toSnake(page.name);
      final classBase = _toPascal(page.name).isEmpty
          ? 'Page$i'
          : _toPascal(page.name);
      final routeBase = '/$fileBase';

      var fileName = '${fileBase}_page.dart';
      var className = '${classBase}Page';
      var routeName = routeBase;

      var suffix = 2;
      while (usedFiles.contains(fileName)) {
        fileName = '${fileBase}_$suffix.dart';
        suffix++;
      }

      suffix = 2;
      while (usedClasses.contains(className)) {
        className = '${classBase}Page$suffix';
        suffix++;
      }

      suffix = 2;
      while (usedRoutes.contains(routeName)) {
        routeName = '$routeBase$suffix';
        suffix++;
      }

      usedFiles.add(fileName);
      usedClasses.add(className);
      usedRoutes.add(routeName);
      specs.add(
        _PageSpec(
          page: page,
          fileName: fileName,
          className: className,
          routeName: routeName,
        ),
      );
    }

    return specs;
  }

  static String _generateProjectMainFile(
    ProjectData project,
    List<_PageSpec> specs,
  ) {
    final appClass = '${_toPascal(project.appName)}App';
    final imports = specs
        .map((spec) => "import 'pages/${spec.fileName}';")
        .join('\n');
    final routes = specs
        .map(
          (spec) =>
              "        '${spec.routeName}': (context) => const ${spec.className}(),",
        )
        .join('\n');

    return '''
import 'package:flutter/material.dart';
$imports

void main() => runApp(const $appClass());

class $appClass extends StatelessWidget {
  const $appClass({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '${_escapeDartString(project.appName)}',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(${project.colorPrimary})),
        useMaterial3: ${project.useMaterial3},
      ),
      initialRoute: '${specs.first.routeName}',
      routes: {
$routes
      },
    );
  }
}
''';
  }

  static String _generatePubspec(
    ProjectData project, {
    required bool hasToast,
  }) {
    final deps = <String>[
      'dependencies:',
      '  flutter:',
      '    sdk: flutter',
      '  cupertino_icons: ^1.0.8',
    ];
    if (hasToast) {
      deps.add('  fluttertoast: ^8.2.2');
    }

    return '''
name: ${_toSnake(project.appName)}
description: Generated by Flutware
publish_to: 'none'
version: ${project.versionName}+${project.versionCode}

environment:
  sdk: ">=3.0.0 <4.0.0"

${deps.join('\n')}

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
''';
  }

  static bool _projectUsesBlockType(List<PageData> pages, String type) {
    bool hasType(List<ActionBlock> actions) {
      for (final action in actions) {
        if (action.type == type) return true;
        if (hasType(action.innerActions)) return true;
        if (hasType(action.elseActions)) return true;
      }
      return false;
    }

    for (final page in pages) {
      if (hasType(page.onCreate)) return true;
      for (final logic in page.logic.values) {
        if (hasType(logic.onPressed)) return true;
        if (hasType(logic.onLongPress)) return true;
      }
    }
    return false;
  }

  static String _asBoolExpression(dynamic value) {
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value == 0 ? 'false' : 'true';
    if (value is String) {
      final raw = value.trim().toLowerCase();
      if (raw == 'true' || raw == 'false') return raw;
      if (raw == '1') return 'true';
      if (raw == '0') return 'false';
      return raw.isEmpty ? 'false' : raw;
    }
    return 'false';
  }

  static List<WidgetData> _flattenWidgets(List<WidgetData> widgets) {
    final out = <WidgetData>[];
    for (final widget in widgets) {
      out.add(widget);
      out.addAll(_flattenWidgets(_childrenOf(widget)));
    }
    return out;
  }

  static WidgetData? _findWidgetById(List<WidgetData> widgets, String id) {
    for (final widget in widgets) {
      if (widget.id == id) return widget;
      final nested = _findWidgetById(_childrenOf(widget), id);
      if (nested != null) return nested;
    }
    return null;
  }

  static String _toSnake(String value) {
    var cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
    if (cleaned.isEmpty) return 'app';
    if (RegExp(r'^[0-9]').hasMatch(cleaned)) {
      cleaned = 'app_$cleaned';
    }
    return cleaned;
  }

  static String _toPascal(String value) {
    final words = value
        .trim()
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'App';
    var result = words
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join();
    if (RegExp(r'^[0-9]').hasMatch(result)) {
      result = 'P$result';
    }
    return result;
  }

  static String _escapeDartString(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
  }
}

class _PageSpec {
  final PageData page;
  final String fileName;
  final String className;
  final String routeName;

  const _PageSpec({
    required this.page,
    required this.fileName,
    required this.className,
    required this.routeName,
  });
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

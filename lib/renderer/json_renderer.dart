import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import 'logic_interpreter.dart';

class JsonRenderer extends StatefulWidget {
  final PageData pageData;
  final ProjectData? projectData;
  final bool isPreview;
  final String? selectedWidgetId;
  final ValueChanged<String>? onWidgetTap;

  const JsonRenderer({
    super.key,
    required this.pageData,
    this.projectData,
    this.isPreview = false,
    this.selectedWidgetId,
    this.onWidgetTap,
  });

  @override
  State<JsonRenderer> createState() => _JsonRendererState();
}

class _JsonRendererState extends State<JsonRenderer> {
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _enabledByWidget = {};
  bool _ranOnCreate = false;

  @override
  void initState() {
    super.initState();
    _syncWidgetStates();
    _runOnCreateIfNeeded();
  }

  @override
  void didUpdateWidget(covariant JsonRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWidgetStates();
    if (oldWidget.pageData.id != widget.pageData.id) {
      _ranOnCreate = false;
      _runOnCreateIfNeeded();
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _parseColor(widget.projectData?.colorPrimary);
    final accentColor = _parseColor(widget.projectData?.colorAccent);

    final appBarWidget = widget.pageData.widgets
        .where((item) => item.type == 'appbar')
        .firstOrNull;
    final fabWidget = widget.pageData.widgets
        .where((item) => item.type == 'fab')
        .firstOrNull;
    final bodyWidgets = widget.pageData.widgets
        .where(
          (item) =>
              (appBarWidget == null || item.id != appBarWidget.id) &&
              (fabWidget == null || item.id != fabWidget.id),
        )
        .toList();

    final bodyRoot = bodyWidgets.firstOrNull;
    final body = bodyRoot == null
        ? const SizedBox.shrink()
        : _buildWidget(
            context,
            bodyRoot,
            primaryColor,
            accentColor,
            insideFlex: false,
          );

    return Scaffold(
      appBar: appBarWidget == null
          ? null
          : AppBar(
              title: Text(
                appBarWidget.properties['title']?.toString() ??
                    widget.pageData.name,
              ),
              backgroundColor: _parseColor(
                appBarWidget.properties['backgroundColor']?.toString(),
              ),
              elevation: 2,
              foregroundColor: Colors.white,
            ),
      backgroundColor: Colors.white,
      floatingActionButton: fabWidget == null
          ? null
          : FloatingActionButton(
              onPressed: () {},
              backgroundColor: accentColor,
              child: const Icon(Icons.add),
            ),
      body: body,
    );
  }

  Widget _buildWidget(
    BuildContext context,
    WidgetData widgetData,
    Color primaryColor,
    Color accentColor, {
    required bool insideFlex,
  }) {
    final children = _readChildren(widgetData);

    switch (widgetData.type) {
      case 'text':
        return _wrapSelectable(
          widgetData,
          Text(
            widgetData.text,
            style: TextStyle(
              fontSize: widgetData.fontSize,
              color: Colors.black87,
            ),
          ),
        );
      case 'button':
        final enabled = _enabledByWidget[widgetData.id] ?? widgetData.enabled;
        final focusNode = _focusNodes.putIfAbsent(widgetData.id, FocusNode.new);
        final buttonColor = _parseColor(
          widgetData.properties['backgroundColor']?.toString(),
          fallback: primaryColor,
        );
        return _wrapSelectable(
          widgetData,
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              focusNode: focusNode,
              onPressed: enabled
                  ? () => _handleEvent(context, widgetData.id, 'onPressed')
                  : null,
              onLongPress: enabled
                  ? () {
                      HapticFeedback.vibrate();
                      _handleEvent(context, widgetData.id, 'onLongPress');
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(widgetData.text),
            ),
          ),
        );
      case 'row':
        final rowChildren = children
            .map(
              (child) => _buildWidget(
                context,
                child,
                primaryColor,
                accentColor,
                insideFlex: true,
              ),
            )
            .toList();
        return _wrapSelectable(
          widgetData,
          Row(
            mainAxisAlignment: _parseMainAxisAlignment(
              widgetData.properties['mainAxisAlignment']?.toString(),
            ),
            crossAxisAlignment: _parseCrossAxisAlignment(
              widgetData.properties['crossAxisAlignment']?.toString(),
            ),
            mainAxisSize: _parseMainAxisSize(
              widgetData.properties['mainAxisSize']?.toString(),
            ),
            textDirection: _parseTextDirection(
              widgetData.properties['textDirection']?.toString(),
            ),
            verticalDirection: _parseVerticalDirection(
              widgetData.properties['verticalDirection']?.toString(),
            ),
            children: rowChildren,
          ),
        );
      case 'column':
        final columnChildren = children
            .map(
              (child) => _buildWidget(
                context,
                child,
                primaryColor,
                accentColor,
                insideFlex: true,
              ),
            )
            .toList();
        return _wrapSelectable(
          widgetData,
          Column(
            mainAxisAlignment: _parseMainAxisAlignment(
              widgetData.properties['mainAxisAlignment']?.toString(),
            ),
            crossAxisAlignment: _parseCrossAxisAlignment(
              widgetData.properties['crossAxisAlignment']?.toString(),
            ),
            mainAxisSize: _parseMainAxisSize(
              widgetData.properties['mainAxisSize']?.toString(),
            ),
            textDirection: _parseTextDirection(
              widgetData.properties['textDirection']?.toString(),
            ),
            verticalDirection: _parseVerticalDirection(
              widgetData.properties['verticalDirection']?.toString(),
            ),
            children: columnChildren,
          ),
        );
      case 'single_scroll':
        final axis = _parseAxis(
          widgetData.properties['scrollDirection']?.toString(),
        );
        final reverse = widgetData.properties['reverse'] == true;
        final padding =
            (widgetData.properties['padding'] as num?)?.toDouble() ?? 0;
        final physics = _parsePhysics(
          widgetData.properties['physics']?.toString(),
        );
        final child = children.isEmpty
            ? const SizedBox.shrink()
            : _buildWidget(
                context,
                children.first,
                primaryColor,
                accentColor,
                insideFlex: false,
              );
        return _wrapSelectable(
          widgetData,
          SingleChildScrollView(
            scrollDirection: axis,
            reverse: reverse,
            physics: physics,
            padding: EdgeInsets.all(padding),
            child: child,
          ),
        );
      case 'padding':
        final padding =
            (widgetData.properties['padding'] as num?)?.toDouble() ?? 0;
        final child = children.isEmpty
            ? const SizedBox.shrink()
            : _buildWidget(
                context,
                children.first,
                primaryColor,
                accentColor,
                insideFlex: false,
              );
        return _wrapSelectable(
          widgetData,
          Padding(padding: EdgeInsets.all(padding), child: child),
        );
      case 'expanded':
        final flex = (widgetData.properties['flex'] as num?)?.toInt() ?? 1;
        final child = children.isEmpty
            ? const SizedBox.shrink()
            : _buildWidget(
                context,
                children.first,
                primaryColor,
                accentColor,
                insideFlex: false,
              );
        if (!insideFlex) {
          return _wrapSelectable(widgetData, child);
        }
        return _wrapSelectable(widgetData, Expanded(flex: flex, child: child));
      default:
        debugPrint('Unknown widget type ignored: ${widgetData.type}');
        return _wrapSelectable(widgetData, const SizedBox.shrink());
    }
  }

  Widget _wrapSelectable(WidgetData widgetData, Widget child) {
    final selected =
        widget.selectedWidgetId != null &&
        widget.selectedWidgetId == widgetData.id;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onWidgetTap == null
          ? null
          : () => widget.onWidgetTap!(widgetData.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: selected
            ? BoxDecoration(
                border: Border.all(color: Colors.lightBlue, width: 2),
                color: Colors.lightBlue.withValues(alpha: 0.1),
              )
            : null,
        child: child,
      ),
    );
  }

  List<WidgetData> _readChildren(WidgetData widgetData) {
    final raw = widgetData.properties['children'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((entry) {
      return WidgetData.fromJson(Map<String, dynamic>.from(entry));
    }).toList();
  }

  Color _parseColor(String? hexString, {Color? fallback}) {
    final base = fallback ?? Colors.blue;
    if (hexString == null || hexString.isEmpty) return base;
    try {
      return Color(int.parse(hexString));
    } catch (_) {
      return base;
    }
  }

  MainAxisAlignment _parseMainAxisAlignment(String? raw) {
    switch (raw) {
      case 'center':
        return MainAxisAlignment.center;
      case 'end':
        return MainAxisAlignment.end;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      case 'start':
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String? raw) {
    switch (raw) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'start':
      default:
        return CrossAxisAlignment.start;
    }
  }

  MainAxisSize _parseMainAxisSize(String? raw) {
    return raw == 'max' ? MainAxisSize.max : MainAxisSize.min;
  }

  TextDirection _parseTextDirection(String? raw) {
    return raw == 'rtl' ? TextDirection.rtl : TextDirection.ltr;
  }

  VerticalDirection _parseVerticalDirection(String? raw) {
    return raw == 'up' ? VerticalDirection.up : VerticalDirection.down;
  }

  Axis _parseAxis(String? raw) {
    return raw == 'horizontal' ? Axis.horizontal : Axis.vertical;
  }

  ScrollPhysics _parsePhysics(String? raw) {
    switch (raw) {
      case 'bouncing':
        return const BouncingScrollPhysics();
      case 'never':
        return const NeverScrollableScrollPhysics();
      case 'clamping':
      default:
        return const ClampingScrollPhysics();
    }
  }

  void _runOnCreateIfNeeded() {
    if (_ranOnCreate) return;
    final blocks = widget.pageData.events.screenOnCreate;
    if (blocks.isEmpty) {
      _ranOnCreate = true;
      return;
    }
    _ranOnCreate = true;
    LogicInterpreter.runBlocks(
      blocks,
      context,
      project: widget.projectData,
      isInitState: true,
      onSetEnabled: _setEnabled,
      onRequestFocus: _requestFocus,
      onNavigatePush: _navigatePush,
      onNavigatePop: _navigatePop,
    );
  }

  void _handleEvent(BuildContext context, String widgetId, String eventName) {
    final events = widget.pageData.events.widgets[widgetId];
    if (events == null) return;
    final blocks = events.eventBlocks(eventName);
    if (blocks.isEmpty) return;

    LogicInterpreter.runBlocks(
      blocks,
      context,
      project: widget.projectData,
      onSetEnabled: _setEnabled,
      onRequestFocus: _requestFocus,
      onNavigatePush: _navigatePush,
      onNavigatePop: _navigatePop,
    );
  }

  void _syncWidgetStates() {
    final all = _flattenWidgets(widget.pageData.widgets);
    final validIds = <String>{};
    for (final item in all) {
      if (item.type == 'button') {
        validIds.add(item.id);
        _enabledByWidget.putIfAbsent(item.id, () => item.enabled);
      }
    }

    final stale = _enabledByWidget.keys
        .where((id) => !validIds.contains(id))
        .toList();
    for (final id in stale) {
      _enabledByWidget.remove(id);
      _focusNodes.remove(id)?.dispose();
    }
  }

  List<WidgetData> _flattenWidgets(List<WidgetData> widgets) {
    final out = <WidgetData>[];
    for (final item in widgets) {
      out.add(item);
      out.addAll(_flattenWidgets(_readChildren(item)));
    }
    return out;
  }

  void _setEnabled(String widgetId, bool enabled) {
    if (!_enabledByWidget.containsKey(widgetId)) return;
    if (!mounted) return;
    setState(() {
      _enabledByWidget[widgetId] = enabled;
    });
  }

  void _requestFocus(String widgetId) {
    if (!mounted) return;
    final node = _focusNodes.putIfAbsent(widgetId, FocusNode.new);
    FocusScope.of(context).requestFocus(node);
  }

  void _navigatePush(String targetPage) {
    if (!mounted || widget.projectData == null) return;

    final project = widget.projectData!;
    PageData? target;
    for (final page in project.pages) {
      if (page.id == targetPage || page.name == targetPage) {
        target = page;
        break;
      }
    }
    if (target == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            JsonRenderer(pageData: target!, projectData: project),
      ),
    );
  }

  void _navigatePop() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

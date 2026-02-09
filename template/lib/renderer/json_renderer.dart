import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import 'logic_interpreter.dart';

class JsonRenderer extends StatelessWidget {
  final PageData pageData;
  final ProjectData? projectData;

  const JsonRenderer({super.key, required this.pageData, this.projectData});

  @override
  Widget build(BuildContext context) {
    final primaryColor = _parseColor(projectData?.colorPrimary);
    final accentColor = _parseColor(projectData?.colorAccent);

    return Scaffold(
      appBar: AppBar(
        title: Text(pageData.name),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: accentColor,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: pageData.widgets
              .map((w) => _buildWidget(context, w, primaryColor, accentColor))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildWidget(
    BuildContext context,
    WidgetData widget,
    Color primaryColor,
    Color accentColor,
  ) {
    switch (widget.type) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            widget.text,
            style: TextStyle(fontSize: widget.fontSize, color: Colors.black87),
          ),
        );
      case 'button':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton(
            onPressed: () => _handleEvent(context, widget.id, 'onClicked'),
            onLongPress: () {
              HapticFeedback.vibrate();
              _handleEvent(context, widget.id, 'onLongPressed');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(widget.text),
          ),
        );
      default:
        return Text('Unknown widget: ${widget.type}');
    }
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.blue;
    try {
      return Color(int.parse(hexString));
    } catch (_) {
      return Colors.blue;
    }
  }

  void _handleEvent(BuildContext context, String widgetId, String eventType) {
    final logic = pageData.logic[widgetId];
    if (logic != null) {
      final actions = eventType == 'onClicked'
          ? logic.onClicked
          : logic.onLongPressed;
      LogicInterpreter.run(actions, context, project: projectData);
    }
  }
}

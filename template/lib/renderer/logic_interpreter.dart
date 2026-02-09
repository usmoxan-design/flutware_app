import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/app_models.dart';
import 'json_renderer.dart';

class LogicInterpreter {
  static void run(
    List<ActionBlock> actions,
    BuildContext context, {
    ProjectData? project,
  }) {
    for (var action in actions) {
      switch (action.type) {
        case 'toast':
          _showToast(action.data['message'] ?? '');
          break;
        case 'snackbar':
          _showSnackBar(context, action.data['message'] ?? '');
          break;
        case 'navigate':
          _navigateTo(context, project, action.data['targetPageId'] ?? '');
          break;
        case 'back':
          Navigator.pop(context);
          break;
        default:
          debugPrint('Unknown action type: ${action.type}');
      }
    }
  }

  static void _navigateTo(
    BuildContext context,
    ProjectData? project,
    String pageId,
  ) {
    if (project == null) return;
    final page = project.pages.firstWhere(
      (p) => p.id == pageId,
      orElse: () => PageData(id: '', name: 'Unknown'),
    );
    if (page.id.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            JsonRenderer(pageData: page, projectData: project),
      ),
    );
  }

  static void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        elevation: 10,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(5),
      ),
    );
  }
}

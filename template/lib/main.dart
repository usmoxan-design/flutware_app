import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/app_models.dart';
import 'renderer/json_renderer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ProjectData? project;
  try {
    final String jsonString = await rootBundle.loadString(
      'assets/project.json',
    );
    project = ProjectData.decode(jsonString);
  } catch (e) {
    debugPrint('Error loading project: \$e');
  }

  runApp(TemplateApp(project: project));
}

class TemplateApp extends StatelessWidget {
  final ProjectData? project;
  const TemplateApp({super.key, this.project});

  @override
  Widget build(BuildContext context) {
    final pages = project?.pages ?? const <PageData>[];
    final firstPage = pages.isEmpty ? null : pages.first;
    return MaterialApp(
      title: project?.appName ?? 'Generated App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: project?.useMaterial3 ?? true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _parseColor(project?.colorPrimary),
        ),
      ),
      home: project == null || firstPage == null
          ? const Scaffold(body: Center(child: Text('No project.json found')))
          : JsonRenderer(pageData: firstPage, projectData: project),
    );
  }

  Color _parseColor(String? raw) {
    if (raw == null || raw.isEmpty) return Colors.blue;
    try {
      return Color(int.parse(raw));
    } catch (_) {
      return Colors.blue;
    }
  }
}

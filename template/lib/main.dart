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
    return MaterialApp(
      title: project?.appName ?? 'Generated App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: project == null
          ? const Scaffold(body: Center(child: Text('No project.json found')))
          : JsonRenderer(pageData: project!.pages.first, projectData: project),
    );
  }
}

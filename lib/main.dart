import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/project_provider.dart';
import 'screens/project_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: FlutwareApp()));
}

class FlutwareApp extends ConsumerWidget {
  const FlutwareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(currentProjectProvider);
    final primary = _parseColor(
      currentProject?.colorPrimary,
      Colors.blueAccent,
    );
    final accent = _parseColor(currentProject?.colorAccent, Colors.deepOrange);
    final appTitle = currentProject?.appName ?? 'Flutterware';

    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          secondary: accent,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accent,
          foregroundColor: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: primary),
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const ProjectListScreen(),
    );
  }

  Color _parseColor(String? value, Color fallback) {
    if (value == null || value.isEmpty) return fallback;
    try {
      return Color(int.parse(value));
    } catch (_) {
      return fallback;
    }
  }
}

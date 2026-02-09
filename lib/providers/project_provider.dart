import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_models.dart';

final projectProvider =
    StateNotifierProvider<ProjectNotifier, List<ProjectData>>((ref) {
      return ProjectNotifier();
    });

class ProjectNotifier extends StateNotifier<List<ProjectData>> {
  ProjectNotifier() : super([]) {
    _loadProjects();
  }

  late Box _box;

  Future<void> _loadProjects() async {
    _box = await Hive.openBox('projects_box');
    final List<dynamic> rawProjects = _box.get('projects', defaultValue: []);
    try {
      state = rawProjects.map((e) => ProjectData.decode(e as String)).toList();
    } catch (e) {
      // If error occurs (likely migration issue), clear state
      state = [];
      _box.put('projects', []);
    }
  }

  Future<void> addProject({
    required String appName,
    required String packageName,
    required String versionCode,
    required String versionName,
    required String colorPrimary,
    required String colorPrimaryDark,
    required String colorAccent,
  }) async {
    final newProject = ProjectData(
      appName: appName,
      packageName: packageName,
      versionCode: versionCode,
      versionName: versionName,
      colorPrimary: colorPrimary,
      colorPrimaryDark: colorPrimaryDark,
      colorAccent: colorAccent,
      pages: [
        PageData(
          id: 'page_home',
          name: 'Home',
          type: 'StatefulWidget',
          widgets: [],
          logic: {},
        ),
      ],
    );
    state = [...state, newProject];
    _save();
  }

  Future<void> updateProject(int index, ProjectData project) async {
    final newState = [...state];
    newState[index] = project;
    state = newState;
    _save();
  }

  Future<void> deleteProject(int index) async {
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
    _save();
  }

  void _save() {
    final rawList = state.map((p) => p.encode()).toList();
    _box.put('projects', rawList);
  }
}

final currentProjectIndexProvider = StateProvider<int?>((ref) => null);
final currentPageIndexProvider = StateProvider<int?>((ref) => null);
final selectedWidgetIdProvider = StateProvider<String?>((ref) => null);

final currentProjectProvider = Provider<ProjectData?>((ref) {
  final index = ref.watch(currentProjectIndexProvider);
  final projects = ref.watch(projectProvider);
  if (index == null || index >= projects.length) return null;
  return projects[index];
});

final currentPageProvider = Provider<PageData?>((ref) {
  final project = ref.watch(currentProjectProvider);
  final pageIndex = ref.watch(currentPageIndexProvider);
  if (project == null ||
      pageIndex == null ||
      pageIndex >= project.pages.length) {
    return null;
  }
  return project.pages[pageIndex];
});

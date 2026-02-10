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

  static const int _maxHistoryDepth = 80;
  late Box _box;
  final Map<int, List<ProjectData>> _undoByProject = {};
  final Map<int, List<ProjectData>> _redoByProject = {};

  Future<void> _loadProjects() async {
    _box = await Hive.openBox('projects_box');
    final List<dynamic> rawProjects = _box.get('projects', defaultValue: []);
    try {
      state = rawProjects.map((e) => ProjectData.decode(e as String)).toList();
      _clearAllHistory();
    } catch (e) {
      // If error occurs (likely migration issue), clear state
      state = [];
      _box.put('projects', []);
      _clearAllHistory();
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
    _clearHistoryFor(state.length - 1);
    _save();
  }

  Future<void> updateProject(
    int index,
    ProjectData project, {
    bool recordHistory = true,
  }) async {
    if (index < 0 || index >= state.length) return;
    final current = state[index];
    if (_sameProject(current, project)) return;

    if (recordHistory) {
      final undoStack = _undoByProject.putIfAbsent(
        index,
        () => <ProjectData>[],
      );
      undoStack.add(current);
      _trimHistory(undoStack);
      _redoByProject.remove(index);
    }

    final newState = [...state];
    newState[index] = project;
    state = newState;
    _save();
  }

  Future<void> deleteProject(int index) async {
    if (index < 0 || index >= state.length) return;
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
    _clearAllHistory();
    _save();
  }

  bool canUndoProject(int index) {
    if (index < 0 || index >= state.length) return false;
    final stack = _undoByProject[index];
    return stack != null && stack.isNotEmpty;
  }

  bool canRedoProject(int index) {
    if (index < 0 || index >= state.length) return false;
    final stack = _redoByProject[index];
    return stack != null && stack.isNotEmpty;
  }

  bool undoProject(int index) {
    if (!canUndoProject(index)) return false;
    final undoStack = _undoByProject[index]!;
    final previous = undoStack.removeLast();
    final redoStack = _redoByProject.putIfAbsent(index, () => <ProjectData>[]);
    redoStack.add(state[index]);
    _trimHistory(redoStack);

    final newState = [...state];
    newState[index] = previous;
    state = newState;
    _save();
    return true;
  }

  bool redoProject(int index) {
    if (!canRedoProject(index)) return false;
    final redoStack = _redoByProject[index]!;
    final next = redoStack.removeLast();
    final undoStack = _undoByProject.putIfAbsent(index, () => <ProjectData>[]);
    undoStack.add(state[index]);
    _trimHistory(undoStack);

    final newState = [...state];
    newState[index] = next;
    state = newState;
    _save();
    return true;
  }

  void _save() {
    final rawList = state.map((p) => p.encode()).toList();
    _box.put('projects', rawList);
  }

  bool _sameProject(ProjectData a, ProjectData b) => a.encode() == b.encode();

  void _trimHistory(List<ProjectData> history) {
    if (history.length <= _maxHistoryDepth) return;
    history.removeRange(0, history.length - _maxHistoryDepth);
  }

  void _clearHistoryFor(int index) {
    _undoByProject.remove(index);
    _redoByProject.remove(index);
  }

  void _clearAllHistory() {
    _undoByProject.clear();
    _redoByProject.clear();
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

final canUndoCurrentProjectProvider = Provider<bool>((ref) {
  final projectIndex = ref.watch(currentProjectIndexProvider);
  ref.watch(projectProvider);
  if (projectIndex == null) return false;
  return ref.read(projectProvider.notifier).canUndoProject(projectIndex);
});

final canRedoCurrentProjectProvider = Provider<bool>((ref) {
  final projectIndex = ref.watch(currentProjectIndexProvider);
  ref.watch(projectProvider);
  if (projectIndex == null) return false;
  return ref.read(projectProvider.notifier).canRedoProject(projectIndex);
});

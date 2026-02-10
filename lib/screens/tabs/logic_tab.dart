import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_models.dart';
import '../../providers/project_provider.dart';
import '../../widgets/compact_block_editor.dart';
import '../logic_editor_screen.dart';

class LogicTab extends ConsumerWidget {
  const LogicTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
    final page = ref.watch(currentPageProvider);
    final projectIndex = ref.watch(currentProjectIndexProvider);
    final pageIndex = ref.watch(currentPageIndexProvider);

    if (project == null ||
        page == null ||
        projectIndex == null ||
        pageIndex == null) {
      return const SizedBox();
    }

    if (page.type == 'StatelessWidget') {
      return const Center(
        child: Text(
          'Stateless page uchun Event mavjud emas',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final widgetIds = _collectWidgetIds(page.widgets);

    return Container(
      color: const Color(0xFFF4F7FB),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openInitStateEditor(
              context,
              ref,
              project,
              page,
              projectIndex,
              pageIndex,
              widgetIds,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E6EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCED6E0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.code, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'initState',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'On page opened',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${page.events.screenOnCreate.length} blok',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openInitStateEditor(
    BuildContext context,
    WidgetRef ref,
    ProjectData project,
    PageData page,
    int projectIndex,
    int pageIndex,
    List<String> widgetIds,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogicEditorScreen(
          title: '${page.name} - initState',
          eventLabel: 'initState',
          project: project,
          page: page,
          scope: BlockEditorScope.onCreate,
          initialBlocks: page.events.screenOnCreate,
          onSave: (blocks) {
            final pages = [...project.pages];
            pages[pageIndex] = page.copyWith(
              events: page.events.withOnCreate(blocks),
            );
            ref
                .read(projectProvider.notifier)
                .updateProject(projectIndex, project.copyWith(pages: pages));
          },
        ),
      ),
    );
  }

  List<String> _collectWidgetIds(List<WidgetData> widgets) {
    final out = <String>[];

    void walk(List<WidgetData> nodes) {
      for (final node in nodes) {
        out.add(node.id);
        final rawChildren = node.properties['children'];
        if (rawChildren is List) {
          final children = rawChildren.whereType<Map>().map((entry) {
            return WidgetData.fromJson(Map<String, dynamic>.from(entry));
          }).toList();
          walk(children);
        }
      }
    }

    walk(widgets);
    return out;
  }
}

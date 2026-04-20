import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';

class WidgetTreePanel extends ConsumerStatefulWidget {
  final ProjectData project;
  final PageData page;
  final String? selectedWidgetId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final bool canPaste;

  const WidgetTreePanel({
    super.key,
    required this.project,
    required this.page,
    required this.selectedWidgetId,
    required this.onSelect,
    required this.onDelete,
    required this.onCopy,
    required this.onPaste,
    required this.canPaste,
  });

  @override
  ConsumerState<WidgetTreePanel> createState() => _WidgetTreePanelState();
}

class _WidgetTreePanelState extends ConsumerState<WidgetTreePanel> {
  final Set<String> _expandedNodes = {};

  @override
  Widget build(BuildContext context) {
    final appBarWidget = widget.page.widgets
        .where((item) => item.type == 'appbar')
        .firstOrNull;
    final fabWidget = widget.page.widgets
        .where((item) => item.type == 'fab')
        .firstOrNull;
    final bodyWidgets = widget.page.widgets
        .where((item) =>
            (appBarWidget == null || item.id != appBarWidget.id) &&
            (fabWidget == null || item.id != fabWidget.id))
        .toList();

    return Container(
      width: 220,
      color: const Color(0xFFF8F9FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree_outlined,
                    size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  'Widget Tree',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                // Copy button
                _buildActionButton(
                  Icons.copy_outlined,
                  widget.onCopy,
                  enabled: widget.selectedWidgetId != null,
                  tooltip: 'Copy (Ctrl+C)',
                ),
                const SizedBox(width: 4),
                // Paste button
                _buildActionButton(
                  Icons.paste_outlined,
                  widget.onPaste,
                  enabled: widget.canPaste,
                  tooltip: 'Paste (Ctrl+V)',
                ),
                const SizedBox(width: 4),
                // Delete button
                _buildActionButton(
                  Icons.delete_outline,
                  widget.onDelete,
                  enabled: widget.selectedWidgetId != null,
                  tooltip: 'Delete (Del)',
                  color: Colors.red,
                ),
              ],
            ),
          ),
          // Tree content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appBarWidget != null)
                    _buildTreeNode(appBarWidget, 0, isSpecial: true),
                  ...bodyWidgets.map((w) => _buildTreeNode(w, 0)),
                  if (fabWidget != null)
                    _buildTreeNode(fabWidget, 0, isSpecial: true),
                ],
              ),
            ),
          ),
          // Keyboard shortcuts hint
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shortcuts:',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                _buildShortcutHint('Ctrl+C', 'Copy'),
                _buildShortcutHint('Ctrl+V', 'Paste'),
                _buildShortcutHint('Delete', 'Remove'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    VoidCallback onTap, {
    required bool enabled,
    required String tooltip,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? (color ?? Colors.grey.shade700)
                : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutHint(String key, String action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              key,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            action,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNode(WidgetData widgetData, int depth,
      {bool isSpecial = false}) {
    final children = _getChildren(widgetData);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedNodes.contains(widgetData.id);
    final isSelected = widgetData.id == widget.selectedWidgetId;

    final iconData = _getWidgetIcon(widgetData.type);
    final iconColor = isSpecial
        ? Colors.orange.shade600
        : _getWidgetColor(widgetData.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onSelect(widgetData.id),
          onDoubleTap: () {
            if (hasChildren) {
              setState(() {
                if (isExpanded) {
                  _expandedNodes.remove(widgetData.id);
                } else {
                  _expandedNodes.add(widgetData.id);
                }
              });
            }
          },
          child: Container(
            height: 36,
            margin: EdgeInsets.only(left: depth * 16.0),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : null,
              border: Border(
                left: BorderSide(
                  color: isSelected ? Colors.blue.shade400 : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                // Expand/collapse icon
                SizedBox(
                  width: 20,
                  child: hasChildren
                      ? InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedNodes.remove(widgetData.id);
                              } else {
                                _expandedNodes.add(widgetData.id);
                              }
                            });
                          },
                          child: Icon(
                            isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : null,
                ),
                // Widget icon
                Icon(iconData, size: 16, color: iconColor),
                const SizedBox(width: 8),
                // Widget name
                Expanded(
                  child: Text(
                    _getWidgetLabel(widgetData),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.blue.shade800
                          : const Color(0xFF334155),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Selected indicator
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Children
        if (hasChildren && isExpanded)
          ...children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  List<WidgetData> _getChildren(WidgetData parent) {
    final childrenIds = parent.properties['children'] as List<dynamic>?;
    if (childrenIds == null) return [];

    return childrenIds
        .map((id) =>
            widget.page.widgets.firstWhere((w) => w.id == id, orElse: () =>
                WidgetData(id: '', type: '', properties: const {})))
        .where((w) => w.id.isNotEmpty)
        .toList();
  }

  IconData _getWidgetIcon(String type) {
    return switch (type) {
      'appbar' => Icons.web_asset,
      'text' => Icons.text_fields,
      'button' => Icons.smart_button,
      'fab' => Icons.add_circle,
      'row' => Icons.view_column,
      'column' => Icons.view_stream,
      'padding' => Icons.space_bar,
      'expanded' => Icons.open_in_full,
      'single_scroll' => Icons.swap_vert,
      'textfield' => Icons.input,
      'image' => Icons.image,
      'icon' => Icons.insert_emoticon,
      'container' => Icons.check_box_outline_blank,
      'card' => Icons.credit_card,
      'listtile' => Icons.list,
      _ => Icons.widgets,
    };
  }

  Color _getWidgetColor(String type) {
    return switch (type) {
      'appbar' || 'fab' => Colors.orange.shade600,
      'text' || 'button' => Colors.blue.shade600,
      'row' || 'column' => Colors.green.shade600,
      'padding' => Colors.purple.shade600,
      'expanded' => Colors.teal.shade600,
      'single_scroll' => Colors.indigo.shade600,
      'textfield' => Colors.amber.shade700,
      'image' => Colors.pink.shade600,
      'icon' => Colors.cyan.shade600,
      'container' => Colors.brown.shade600,
      _ => Colors.grey.shade600,
    };
  }

  String _getWidgetLabel(WidgetData widget) {
    final typeLabel = widget.type[0].toUpperCase() + widget.type.substring(1);
    final customName = widget.properties['label'] ??
        widget.properties['text'] ??
        widget.properties['title'] ??
        widget.properties['hint'];

    if (customName != null && customName.toString().isNotEmpty) {
      final truncated = customName.toString().length > 15
          ? '${customName.toString().substring(0, 15)}...'
          : customName.toString();
      return '$typeLabel ($truncated)';
    }
    return typeLabel;
  }
}

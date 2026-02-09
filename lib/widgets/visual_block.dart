import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/block_definitions.dart';

class VisualBlockWidget extends StatelessWidget {
  final ActionBlock action;
  final VoidCallback? onDelete;
  final String? targetPageName;
  final bool isHat;
  final Widget? innerContent;
  final Widget? elseContent;

  const VisualBlockWidget({
    super.key,
    required this.action,
    this.onDelete,
    this.targetPageName,
    this.isHat = false,
    this.innerContent,
    this.elseContent,
  });

  @override
  Widget build(BuildContext context) {
    final def = BlockRegistry.get(action.type);
    final color = def?.category.color ?? Colors.grey;
    final title = def?.title ?? action.type;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.fromLTRB(10, isHat ? 14 : 8, 10, 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (onDelete != null)
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
            ],
          ),
          if (innerContent != null) ...[
            const SizedBox(height: 6),
            innerContent!,
          ],
          if (elseContent != null) ...[const SizedBox(height: 6), elseContent!],
        ],
      ),
    );
  }
}

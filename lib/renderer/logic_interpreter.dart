import 'package:flutter/material.dart';

import '../engine/block_executor.dart';
import '../models/app_models.dart';

class LogicInterpreter {
  static void run(
    List<ActionBlock> actions,
    BuildContext context, {
    ProjectData? project,
    bool isInitState = false,
    BlockSetEnabled? onSetEnabled,
    BlockRequestFocus? onRequestFocus,
    BlockNavigatePush? onNavigatePush,
    BlockNavigatePop? onNavigatePop,
  }) {
    final blocks = actions.map(BlockModel.fromActionBlock).toList();
    runBlocks(
      blocks,
      context,
      project: project,
      isInitState: isInitState,
      onSetEnabled: onSetEnabled,
      onRequestFocus: onRequestFocus,
      onNavigatePush: onNavigatePush,
      onNavigatePop: onNavigatePop,
    );
  }

  static void runBlocks(
    List<BlockModel> blocks,
    BuildContext context, {
    ProjectData? project,
    bool isInitState = false,
    BlockSetEnabled? onSetEnabled,
    BlockRequestFocus? onRequestFocus,
    BlockNavigatePush? onNavigatePush,
    BlockNavigatePop? onNavigatePop,
  }) {
    BlockExecutor.run(
      blocks,
      BlockExecutionContext(
        context: context,
        project: project,
        isInitState: isInitState,
        onSetEnabled: onSetEnabled,
        onRequestFocus: onRequestFocus,
        onNavigatePush: onNavigatePush,
        onNavigatePop: onNavigatePop,
      ),
    );
  }
}

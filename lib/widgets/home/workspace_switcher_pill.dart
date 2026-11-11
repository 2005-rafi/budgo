import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense/design/tokens/app_radius.dart';
import 'package:expense/design/tokens/app_spacing.dart';
import 'package:expense/design/tokens/entity_icons.dart';
import 'package:expense/models/workspace_type.dart';
import 'package:expense/providers/workspace_provider.dart';
import 'package:expense/widgets/sheets/workspace_switcher_sheet.dart';

class WorkspaceSwitcherPill extends StatelessWidget {
  const WorkspaceSwitcherPill({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workspaceProvider = context.watch<WorkspaceProvider>();
    final activeWs = workspaceProvider.activeWorkspace;
    final name = activeWs?.name ?? 'Personal';
    final type = activeWs?.type ?? WorkspaceType.personal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const WorkspaceSwitcherSheet(),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                WorkspaceIcons.forType(type),
                size: 16,
                color: Color(activeWs?.colorValue ?? colorScheme.primary.toARGB32()),
              ),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

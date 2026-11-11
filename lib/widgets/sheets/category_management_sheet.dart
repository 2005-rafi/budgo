import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/registries/curated_icons_catalog.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/user_category.dart';
import 'package:expense/providers/category_provider.dart';
import 'package:expense/widgets/sheets/category_form_sheet.dart';

class CategoryManagementSheet extends StatelessWidget {
  const CategoryManagementSheet({super.key});

  static void show(BuildContext context) {
    BudgoBottomSheet.show(
      context,
      builder: (context) => const CategoryManagementSheet(),
    );
  }

  void _confirmArchive(BuildContext context, UserCategory category) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Archive "${category.name}"?',
      message:
          'This category will no longer appear when logging new transactions. Existing transactions will keep their original name, icon, and colors.',
      confirmLabel: 'Archive',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      final provider = context.read<CategoryProvider>();
      final success = await provider.archiveCategory(category.id);
      if (context.mounted) {
        if (success) {
          SnackbarFeedback.showSuccess(context, 'Category "${category.name}" archived');
        } else {
          SnackbarFeedback.showError(
            context,
            provider.lastError ?? provider.errorMessage ?? 'Unable to archive category.',
            operation: FeedbackOperation.archiveCategory,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catProvider = context.watch<CategoryProvider>();
    final categories = catProvider.categories;

    return BudgoBottomSheet(
      title: 'Manage Categories',
      subtitle: '${catProvider.activeCount} of ${AppConstants.kMaxCategoryLimit} categories',
      maxHeightFactor: 0.85,
      footer: BudgoButton(
        label: catProvider.canAddMore
            ? 'Add Category'
            : 'Category Limit Reached (12/12)',
        icon: Icons.add,
        onPressed: catProvider.canAddMore
            ? () => CategoryFormSheet.show(context)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Drag to reorder. The top 4 appear as quick chips on Add Expense.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Categories Reorderable List
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                catProvider.reorderCategories(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final cat = categories[index];
                final pair = CuratedIconsCatalog.get(cat.iconId);
                final isTop4 = index < 4;

                return Material(
                  key: ValueKey(cat.id),
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isTop4
                            ? colorScheme.primary.withValues(alpha: 0.3)
                            : colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(cat.colorValue).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          pair.filled,
                          size: 20,
                          color: Color(cat.colorValue),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              cat.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isTop4) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'Top 4',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        pair.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Edit Category',
                            onPressed: () => CategoryFormSheet.show(
                              context,
                              existingCategory: cat,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.archive_outlined,
                              size: 20,
                              color: categories.length > 1
                                  ? colorScheme.error
                                  : colorScheme.outlineVariant,
                            ),
                            tooltip: categories.length > 1
                                ? 'Archive Category'
                                : 'Must have at least 1 category',
                            onPressed: categories.length > 1
                                ? () => _confirmArchive(context, cat)
                                : null,
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.drag_handle, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

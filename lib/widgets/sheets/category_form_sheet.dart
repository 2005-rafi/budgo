import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/core/constants/app_constants.dart';
import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/registries/curated_icons_catalog.dart';
import 'package:expense/design/budgo_ui.dart';
import 'package:expense/models/user_category.dart';
import 'package:expense/providers/category_provider.dart';

class CategoryFormSheet extends StatefulWidget {
  final UserCategory? existingCategory;

  const CategoryFormSheet({super.key, this.existingCategory});

  static void show(BuildContext context, {UserCategory? existingCategory}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryFormSheet(existingCategory: existingCategory),
    );
  }

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _nameController = TextEditingController();
  late String _selectedIconId;
  late int _selectedColorValue;
  String _selectedDomain = 'All';
  String? _nameError;
  bool _isSaving = false;

  static const List<int> _palette = [
    0xFFE57373, // Coral Red
    0xFF4FC3F7, // Sky Blue
    0xFF81C784, // Soft Green
    0xFFFFB74D, // Warm Amber
    0xFFBA68C8, // Lavender Purple
    0xFFFF8A65, // Deep Apricot
    0xFF4DB6AC, // Minty Teal
    0xFF5C6BC0, // Indigo
    0xFF7E57C2, // Deep Purple
    0xFF26A69A, // Rich Teal
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingCategory != null) {
      _nameController.text = widget.existingCategory!.name;
      _selectedIconId = widget.existingCategory!.iconId;
      _selectedColorValue = widget.existingCategory!.colorValue;
    } else {
      _selectedIconId = 'category';
      _selectedColorValue = _palette.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _validateName(String value) {
    setState(() {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        _nameError = 'Category name is required';
      } else if (trimmed.length > AppConstants.kMaxCategoryNameLength) {
        _nameError = 'Max ${AppConstants.kMaxCategoryNameLength} characters allowed';
      } else {
        _nameError = null;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Category name is required');
      return;
    }
    if (name.length > AppConstants.kMaxCategoryNameLength) {
      setState(() => _nameError = 'Max ${AppConstants.kMaxCategoryNameLength} characters allowed');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<CategoryProvider>();

    bool success;
    if (widget.existingCategory != null) {
      final updated = widget.existingCategory!.copyWith(
        name: name,
        iconId: _selectedIconId,
        colorValue: _selectedColorValue,
      );
      success = await provider.updateCategory(updated);
    } else {
      success = await provider.addCategory(
        name: name,
        iconId: _selectedIconId,
        colorValue: _selectedColorValue,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      SnackbarFeedback.showSuccess(
        context,
        widget.existingCategory != null
            ? 'Category "$name" updated'
            : 'Category "$name" created',
      );
    } else {
      SnackbarFeedback.showError(
        context,
        provider.lastError ?? provider.errorMessage ?? 'Unable to save category.',
        operation: FeedbackOperation.saveCategory,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEdit = widget.existingCategory != null;

    final List<CuratedIconPair> displayedIcons = _selectedDomain == 'All'
        ? CuratedIconsCatalog.allIcons
        : CuratedIconsCatalog.forDomain(_selectedDomain);

    final selectedPair = CuratedIconsCatalog.get(_selectedIconId);

    return BudgoBottomSheet(
      title: isEdit ? 'Edit Category' : 'New Category',
      icon: selectedPair.filled,
      iconColor: Color(_selectedColorValue),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      footer: BudgoButton(
        label: isEdit ? 'Save Changes' : 'Create Category',
        isLoading: _isSaving,
        onPressed: _save,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Preview Badge
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(_selectedColorValue).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Color(_selectedColorValue),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedPair.filled,
                      size: 18,
                      color: Color(_selectedColorValue),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _nameController.text.trim().isNotEmpty
                          ? _nameController.text.trim()
                          : 'Preview',
                      style: TextStyle(
                        color: Color(_selectedColorValue),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Name Input with dynamic character counter
            BudgoTextField(
              controller: _nameController,
              inputPolicy: BudgoInputPolicy.categoryName,
              textCapitalization: TextCapitalization.words,
              label: 'Category Name',
              hint: 'Enter category name for quick tagging',
              errorText: _nameError,
              onChanged: (val) {
                _validateName(val);
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Color Chooser
            Text(
              'Color Accent',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _palette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final color = _palette[index];
                  final isSelected = _selectedColorValue == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorValue = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.onSurface
                              : Colors.transparent,
                          width: isSelected ? 3 : 0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(color).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Icon Picker Header & Domain Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Icon (${CuratedIconsCatalog.allIcons.length} available)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  selectedPair.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            BudgoChoiceGroup<String>(
              allowHorizontalScroll: true,
              selectedValue: _selectedDomain,
              options: ['All', ...CuratedIconsCatalog.domains]
                  .map((d) => BudgoChoiceOption(value: d, label: d))
                  .toList(),
              onSelected: (domain) => setState(() => _selectedDomain = domain),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Icon Grid
            Container(
              height: 190,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: GridView.builder(
                itemCount: displayedIcons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final pair = displayedIcons[index];
                  final isSelected = _selectedIconId == pair.id;
                  return InkWell(
                    onTap: () => setState(() => _selectedIconId = pair.id),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isSelected ? pair.filled : pair.outlined,
                        size: 22,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


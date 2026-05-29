import 'package:flutter/material.dart';
import 'package:expense/core/app_constants.dart';
import 'package:expense/core/app_spacing.dart';

class QuickFilterBar extends StatefulWidget {
  final Set<String> initialFilters;
  final ValueChanged<Set<String>> onFiltersChanged;

  const QuickFilterBar({
    super.key,
    required this.initialFilters,
    required this.onFiltersChanged,
  });

  @override
  State<QuickFilterBar> createState() => _QuickFilterBarState();
}

class _QuickFilterBarState extends State<QuickFilterBar> {
  late final Set<String> _activeFilters;

  @override
  void initState() {
    super.initState();
    _activeFilters = Set.from(widget.initialFilters);
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (filter == 'All') {
        _activeFilters.clear();
      } else {
        if (_activeFilters.contains(filter)) {
          _activeFilters.remove(filter);
        } else {
          // Mutually exclusive date chips
          if (filter == 'This Week') {
            _activeFilters.remove('This Month');
          } else if (filter == 'This Month') {
            _activeFilters.remove('This Week');
          }
          _activeFilters.add(filter);
        }
      }
      widget.onFiltersChanged(Set.from(_activeFilters));
    });
  }

  @override
  Widget build(BuildContext context) {
    final allChips = [
      'All',
      ...AppConstants.kDefaultCategories,
      'This Week',
      'This Month',
      'High Spend',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: allChips.map((chip) {
          final isSelected = chip == 'All' 
              ? _activeFilters.isEmpty 
              : _activeFilters.contains(chip);

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              selected: isSelected,
              label: Text(chip),
              onSelected: (_) => _toggleFilter(chip),
            ),
          );
        }).toList(),
      ),
    );
  }
}

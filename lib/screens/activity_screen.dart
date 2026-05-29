import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense/core/app_layout.dart';
import 'package:expense/core/app_radius.dart';
import 'package:expense/core/app_spacing.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/models/timeline_group.dart';
import 'package:expense/models/transaction_entry.dart';
import 'package:expense/provider/activity_provider.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:expense/provider/future_expenses_provider.dart';
import 'package:expense/provider/income_provider.dart';

import 'package:expense/widgets/common/app_transaction_tile.dart';
import 'package:expense/widgets/common/app_filter_chip.dart';
import 'package:expense/widgets/common/app_section_header.dart';
import 'package:expense/widgets/common/reminder_action_badge.dart';

import 'package:expense/widgets/confirmation_dialog.dart';
import 'package:expense/widgets/forms/transaction_detail_sheet.dart';
import 'package:expense/widgets/snackbar_feedback.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late FilterCriteria _criteria;
  final int _pageSize = 50;
  int _currentPage = 1;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _criteria = const FilterCriteria();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is FilterCriteria) {
        _criteria = args;
        if (_criteria.searchQuery.isNotEmpty) {
          _searchController.text = _criteria.searchQuery;
        }
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() {
      _currentPage++;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _criteria = _criteria.copyWith(searchQuery: query);
      _currentPage = 1;
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return _FilterBottomSheetContent(
          initialCriteria: _criteria,
          onApply: (confirmedCriteria) {
            setState(() {
              _criteria = confirmedCriteria;
              _currentPage = 1;
            });
          },
        );
      },
    );
  }

  void _clearSpecificFilter(String type) {
    setState(() {
      if (type == 'date') {
        _criteria = _criteria.copyWith(date: null, dateRange: null);
        final cats = Set<String>.from(_criteria.categories)
          ..removeAll({'Today', 'This Week', 'This Month'});
        _criteria = _criteria.copyWith(categories: cats);
      }
      if (type == 'search') {
        _criteria = _criteria.copyWith(searchQuery: '');
        _searchController.clear();
      }
      _currentPage = 1;
    });
  }

  bool _isDefaultFilter() {
    return _criteria.searchQuery.isEmpty &&
        _criteria.categories.isEmpty &&
        _criteria.date == null &&
        _criteria.dateRange == null;
  }

  void _handleDelete(BuildContext context, TransactionEntry entry) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Transaction?',
      message: 'Are you sure you want to permanently delete this record?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirm) {
      if (!context.mounted) return;
      try {
        if (entry is ExpenseEntry) {
          await context.read<ExpensesProvider>().deleteExpense(
            entry.rawExpense,
          );
        } else if (entry is IncomeEntry) {
          await context.read<IncomeProvider>().deleteIncome(entry.rawIncome);
        } else if (entry is PlannedEntry) {
          await context.read<FutureExpensesProvider>().deleteFutureExpense(
            entry.rawFuture,
          );
        }
        if (context.mounted) {
          SnackbarFeedback.showSuccess(
            context,
            'Transaction deleted successfully.',
          );
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarFeedback.showError(
            context,
            'Failed to delete transaction: $e',
          );
        }
      }
    }
  }

  void _handleConfirm(BuildContext context, IncomeEntry entry) async {
    try {
      await context.read<IncomeProvider>().confirmSingle(entry.rawIncome);
      if (context.mounted) {
        SnackbarFeedback.showSuccess(context, 'Income confirmed.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarFeedback.showError(context, 'Failed to confirm income: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: const [
          ReminderActionBadge(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        left: true,
        right: true,
        top: false,
        bottom: false,
        child: Selector4<
            ActivityProvider,
            ExpensesProvider,
            IncomeProvider,
            FutureExpensesProvider,
            (List<TimelineGroup>, bool)
        >(
          selector: (ctx, ap, ep, ip, fep) {
            final filteredExpenses = ap.filtered(ep.allExpenses, _criteria);
            final groups = ap.service.buildTimeline(
              filteredExpenses: filteredExpenses,
              allIncomes: ip.items,
              allFutureExpenses: fep.items,
              criteria: _criteria,
            );
            
            final isLoading = ep.isLoading || ip.isLoading || fep.isLoading;
            return (groups, isLoading);
          },
          builder: (context, data, _) {
            final groups = data.$1;
            final isLoading = data.$2;

            // Apply Paging locally
            int totalItemsInGroups = groups.fold<int>(0, (sum, g) => sum + g.items.length);
            int limit = _currentPage * _pageSize;
            int currentCount = 0;
            final List<TimelineGroup> pagedGroups = [];

            for (final group in groups) {
              if (currentCount >= limit) break;
              final int remaining = limit - currentCount;
              if (group.items.length <= remaining) {
                pagedGroups.add(group);
                currentCount += group.items.length;
              } else {
                pagedGroups.add(
                  TimelineGroup(
                    title: group.title,
                    items: group.items.take(remaining).toList(),
                  ),
                );
                currentCount += remaining;
                break;
              }
            }

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Zone 1 — Sticky Search & Filter Header
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchFilterHeaderDelegate(
                    searchController: _searchController,
                    onSearchChanged: _onSearchChanged,
                    activeFilter: _criteria,
                    onFilterPressed: _showFilterSheet,
                    onClearSearch: () => _clearSpecificFilter('search'),
                    statusBarHeight: 0.0,
                  ),
                ),

                // Zone 2 — Filter Result Banner (if active)
                if (!_isDefaultFilter())
                  SliverToBoxAdapter(
                    child: AppSectionHeader(
                      label: 'Filtered: $totalItemsInGroups results',
                      trailingLabel: 'Clear all',
                      onTrailingTap: () {
                        setState(() {
                          _criteria = const FilterCriteria();
                          _searchController.clear();
                          _currentPage = 1;
                        });
                      },
                    ),
                  ),

                // Zone 3 — Loading / Empty / Content states
                if (isLoading && groups.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.filter_list_off,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No results',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Try adjusting your filters',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _criteria = const FilterCriteria();
                                  _searchController.clear();
                                  _currentPage = 1;
                                });
                              },
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...pagedGroups.expand((group) {
                    return [
                      // Sticky Date Section Header
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyGroupHeaderDelegate(title: group.title),
                      ),
                      // Group list
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding(context),
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final entry = group.items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                        child: AppTransactionTile(
                                  title: entry.displayName,
                                  amount: entry.amount,
                                  category: entry.category,
                                  date: entry.date,
                                  isIncome: entry is IncomeEntry,
                                  isPending: entry is IncomeEntry && !entry.isConfirmed,
                                  isPlanned: entry is PlannedEntry,
                                  onTap: () => TransactionDetailSheet.show(context, entry),
                                  onDelete: () => _handleDelete(context, entry),
                                  onConfirm: entry is IncomeEntry
                                      ? () => _handleConfirm(context, entry)
                                      : null,
                                ),
                              );
                            },
                            childCount: group.items.length,
                          ),
                        ),
                      ),
                    ];
                  }),

                // Paging loading footer
                if (currentCount < totalItemsInGroups)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),

                // Safe bottom padding spacing clearance
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + AppSpacing.bottomNavClear,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final FilterCriteria activeFilter;
  final VoidCallback onFilterPressed;
  final VoidCallback onClearSearch;
  final double statusBarHeight;

  _SearchFilterHeaderDelegate({
    required this.searchController,
    required this.onSearchChanged,
    required this.activeFilter,
    required this.onFilterPressed,
    required this.onClearSearch,
    required this.statusBarHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasActiveFilters = activeFilter.categories.isNotEmpty ||
        activeFilter.date != null ||
        activeFilter.dateRange != null;

    return Container(
      height: maxExtent,
      color: colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // M3 Search Bar
          Padding(
            padding: EdgeInsets.only(
              left: AppLayout.screenPadding(context),
              right: AppLayout.screenPadding(context),
              top: statusBarHeight + AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: SizedBox(
              height: 48,
              child: SearchBar(
                controller: searchController,
                hintText: 'Search transactions',
                hintStyle: WidgetStateProperty.all(
                  theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                leading: Icon(
                  Icons.search,
                  color: colorScheme.onSurfaceVariant,
                ),
                trailing: [
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                      onPressed: onClearSearch,
                    ),
                  IconButton(
                    icon: Icon(
                      hasActiveFilters ? Icons.filter_list_alt : Icons.filter_list,
                      color: hasActiveFilters ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Filter',
                    onPressed: onFilterPressed,
                  ),
                ],
                onChanged: onSearchChanged,
                elevation: WidgetStateProperty.all(0.0),
                backgroundColor: WidgetStateProperty.all(
                  colorScheme.surfaceContainerHigh,
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 64.0 + statusBarHeight;

  @override
  double get minExtent => 64.0 + statusBarHeight;

  @override
  bool shouldRebuild(covariant _SearchFilterHeaderDelegate oldDelegate) {
    return true;
  }
}

class _StickyGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _StickyGroupHeaderDelegate({required this.title});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      color: colorScheme.surface,
      height: 40.0,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 40.0;

  @override
  double get minExtent => 40.0;

  @override
  bool shouldRebuild(covariant _StickyGroupHeaderDelegate oldDelegate) {
    return true;
  }
}

class _FilterBottomSheetContent extends StatefulWidget {
  final FilterCriteria initialCriteria;
  final ValueChanged<FilterCriteria> onApply;

  const _FilterBottomSheetContent({
    required this.initialCriteria,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheetContent> createState() => _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<_FilterBottomSheetContent> {
  late FilterCriteria _localCriteria;

  @override
  void initState() {
    super.initState();
    _localCriteria = widget.initialCriteria;
  }

  void _toggleFilter(String filter) {
    final activeCategories = Set<String>.from(_localCriteria.categories);
    final row1Items = {'Income', 'Rent', 'Food', 'Entertainment', 'Shopping', 'Travel', 'Lend/Borrow', 'Other'};
    final row2Items = {'Today', 'This Week', 'This Month'};

    if (filter == 'All') {
      activeCategories.removeAll(row1Items);
    } else if (row1Items.contains(filter)) {
      if (activeCategories.contains(filter)) {
        activeCategories.remove(filter);
      } else {
        activeCategories.removeAll(row1Items);
        activeCategories.add(filter);
      }
    } else if (row2Items.contains(filter)) {
      if (activeCategories.contains(filter)) {
        activeCategories.remove(filter);
      } else {
        activeCategories.removeAll(row2Items);
        activeCategories.add(filter);
      }
    } else if (filter == 'High Spend') {
      if (activeCategories.contains('High Spend')) {
        activeCategories.remove('High Spend');
      } else {
        activeCategories.add('High Spend');
      }
    }

    setState(() {
      _localCriteria = _localCriteria.copyWith(categories: activeCategories);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final row1List = ['All', 'Income', 'Rent', 'Food', 'Entertainment', 'Shopping', 'Travel', 'Lend/Borrow', 'Other'];
    final row2List = ['Today', 'This Week', 'This Month'];

    final activeCats = _localCriteria.categories;
    final isAllSelected = !activeCats.any((c) => row1List.contains(c) && c != 'All');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Transactions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _localCriteria = const FilterCriteria();
                    });
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Section 1: Tags
            Text(
              'Tags / Category',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: row1List.map((chip) {
                final isSelected = chip == 'All' ? isAllSelected : activeCats.contains(chip);
                return AppFilterChip(
                  label: chip,
                  selected: isSelected,
                  onSelected: (_) => _toggleFilter(chip),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Section 2: Timing
            Text(
              'Timing',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: row2List.map((chip) {
                final isSelected = activeCats.contains(chip);
                return AppFilterChip(
                  label: chip,
                  selected: isSelected,
                  onSelected: (_) => _toggleFilter(chip),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Section 3: Smart Filters
            Text(
              'Smart Filters',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppFilterChip(
                  label: 'High Spend',
                  selected: activeCats.contains('High Spend'),
                  onSelected: (_) => _toggleFilter('High Spend'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Confirm Button
            FilledButton(
              onPressed: () {
                widget.onApply(_localCriteria);
                Navigator.pop(context);
              },
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

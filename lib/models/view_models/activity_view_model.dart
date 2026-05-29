import 'package:flutter/foundation.dart';
import 'package:expense/models/filter_criteria.dart';
import 'package:expense/models/timeline_group.dart';

@immutable
class ActivityViewModel {
  final List<TimelineGroup> groups;
  final FilterCriteria activeFilter;
  final bool hasMore;
  final bool isLoading;
  final String? errorMessage;

  const ActivityViewModel({
    required this.groups,
    required this.activeFilter,
    required this.hasMore,
    this.isLoading = false,
    this.errorMessage,
  });

  factory ActivityViewModel.empty() => const ActivityViewModel(
        groups: [],
        activeFilter: FilterCriteria(),
        hasMore: false,
      );
}

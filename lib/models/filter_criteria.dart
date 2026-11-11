import 'package:flutter/material.dart';

class FilterCriteria {
  final String searchQuery;
  final Set<String> categories;
  final DateTime? date;
  final DateTimeRange? dateRange;
  final bool highSpendOnly;
  final String? paymentMethod;

  const FilterCriteria({
    this.searchQuery = '',
    this.categories = const {},
    this.date,
    this.dateRange,
    this.highSpendOnly = false,
    this.paymentMethod,
  });

  FilterCriteria copyWith({
    String? searchQuery,
    Set<String>? categories,
    DateTime? date,
    DateTimeRange? dateRange,
    bool? highSpendOnly,
    String? paymentMethod,
  }) {
    return FilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      categories: categories ?? this.categories,
      date: date ?? this.date,
      dateRange: dateRange ?? this.dateRange,
      highSpendOnly: highSpendOnly ?? this.highSpendOnly,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'transaction_entry.dart';

@immutable
class TimelineGroup {
  final String title; // e.g. "Today", "Yesterday", "May 2026"
  final List<TransactionEntry> items;

  const TimelineGroup({
    required this.title,
    required this.items,
  });
}

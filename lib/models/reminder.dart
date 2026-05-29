import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:expense/core/money.dart';

part 'reminder.g.dart';

enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
}

class RecurrenceRule {
  final RecurrenceType type;
  final int? weekday; // 1-7 for weekly
  final int? dayOfMonth; // 1-28 for monthly (capped at 28)
  final TimeOfDay time;

  RecurrenceRule({
    required this.type,
    this.weekday,
    this.dayOfMonth,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'weekday': weekday,
    'dayOfMonth': dayOfMonth == null ? null : min(dayOfMonth!, 28),
    'hour': time.hour,
    'minute': time.minute,
  };

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      type: RecurrenceType.values.firstWhere((e) => e.name == json['type'], orElse: () => RecurrenceType.none),
      weekday: json['weekday'] as int?,
      dayOfMonth: json['dayOfMonth'] as int?,
      time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
    );
  }

  static int lastDayOfMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const daysInMonths = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonths[month];
  }

  DateTime nextOccurrenceAfter(DateTime from, DateTime baseDateTime) {
    var candidate = DateTime(
      baseDateTime.year,
      baseDateTime.month,
      baseDateTime.day,
      time.hour,
      time.minute,
    );

    if (type == RecurrenceType.none) {
      return baseDateTime;
    }

    while (candidate.isBefore(from)) {
      if (type == RecurrenceType.daily) {
        candidate = candidate.add(const Duration(days: 1));
      } else if (type == RecurrenceType.weekly) {
        final targetWeekday = weekday ?? baseDateTime.weekday;
        int daysDiff = targetWeekday - candidate.weekday;
        if (daysDiff < 0 || (daysDiff == 0 && candidate.isBefore(from))) {
          daysDiff += 7;
        }
        candidate = candidate.add(Duration(days: daysDiff));
        while (candidate.isBefore(from)) {
          candidate = candidate.add(const Duration(days: 7));
        }
      } else if (type == RecurrenceType.monthly) {
        int nextYear = candidate.year;
        int nextMonth = candidate.month + 1;
        if (nextMonth > 12) {
          nextYear += 1;
          nextMonth = 1;
        }
        final maxDay = lastDayOfMonth(nextYear, nextMonth);
        final targetDay = min(dayOfMonth ?? baseDateTime.day, maxDay);
        candidate = DateTime(
          nextYear,
          nextMonth,
          targetDay,
          time.hour,
          time.minute,
        );
      }
    }
    return candidate;
  }

  static DateTime computeLegacyNextOccurrence(
    DateTime scheduledAt,
    String legacyType,
    DateTime from,
  ) {
    DateTime next = scheduledAt;
    while (next.isBefore(from)) {
      if (legacyType == 'daily') {
        next = next.add(const Duration(days: 1));
      } else if (legacyType == 'weekly') {
        next = next.add(const Duration(days: 7));
      } else if (legacyType == 'monthly') {
        int year = next.year;
        int month = next.month + 1;
        if (month > 12) {
          year += 1;
          month = 1;
        }
        int day = min(next.day, lastDayOfMonth(year, month));
        next = DateTime(year, month, day, next.hour, next.minute);
      } else {
        break;
      }
    }
    return next;
  }
}

// SCHEMA VERSION: 3
// Version 1: fields 0-6
// Version 2: added field 7 (recurrenceRuleJson, nullable String)
// Version 3: added field 10 (amount, nullable int) and 11 (category, nullable String)
@HiveType(typeId: 4)
class Reminder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? notes;

  @HiveField(3)
  DateTime scheduledAt;

  @HiveField(4)
  bool isRecurring;

  @HiveField(5)
  String recurrenceType; // Kept for backwards compatibility

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  String? recurrenceRuleJson;

  @HiveField(8, defaultValue: 'active')
  String state; // 'scheduling', 'active', 'failed'

  @HiveField(9)
  String? failureReason;

  @HiveField(10)
  int? amount; // Amount in paise

  @HiveField(11)
  String? category; // Payment Category

  Reminder({
    required this.id,
    required this.title,
    this.notes,
    required this.scheduledAt,
    this.isRecurring = false,
    this.recurrenceType = 'none',
    this.isActive = true,
    this.recurrenceRuleJson,
    this.state = 'active',
    this.failureReason,
    this.amount,
    this.category,
  });

  RecurrenceRule? get recurrenceRule {
    if (recurrenceRuleJson == null) return null;
    try {
      return RecurrenceRule.fromJson(jsonDecode(recurrenceRuleJson!));
    } catch (_) {
      return null;
    }
  }

  set recurrenceRule(RecurrenceRule? rule) {
    if (rule == null) {
      recurrenceRuleJson = null;
    } else {
      recurrenceRuleJson = jsonEncode(rule.toJson());
    }
  }

  int get notificationId => id.hashCode & 0x7FFFFFFF;

  String get notificationBody {
    final buffer = StringBuffer();
    if (amount != null && amount! > 0) {
      buffer.write('Amount: ${amount!.format()}');
    }
    if (category != null && category!.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' • ');
      buffer.write('Category: $category');
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(notes!.trim());
    }
    if (buffer.isEmpty) {
      buffer.write('Upcoming financial reminder');
    }
    return buffer.toString();
  }
}

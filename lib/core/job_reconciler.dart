import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:expense/models/job_record.dart';
import 'package:expense/models/reminder.dart';
import 'package:expense/services/notification_service.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/future_expense.dart';
import 'package:expense/provider/finance_boxes.dart';

class JobReconciler {
  static Future<void> reconcile() async {
    await cleanupTempExports();

    // 1. Reconcile Durable Jobs
    final Box<JobRecord> jobsBox = Hive.box<JobRecord>('jobs');
    final pendingJobs = jobsBox.values
        .where((job) => job.state == 'pending')
        .toList();

    for (final job in pendingJobs) {
      try {
        if (job.type == 'purchase') {
          await _reconcilePurchase(job);
        } else {
          // Idempotent/other tasks can be closed
          job.state = 'complete';
          await job.save();
        }
      } catch (e) {
        job.state = 'failed';
        await job.save();
      }
    }

    // 2. Reconcile Reminders in 'scheduling' state (Task 3-7)
    final Box<Reminder> remindersBox = Hive.box<Reminder>('reminders');
    final schedulingReminders = remindersBox.values
        .where((r) => r.state == 'scheduling')
        .toList();

    if (schedulingReminders.isNotEmpty) {
      // notificationService.initialize() should have been called or will be called.
      // Actually, main.dart calls reconcile() BEFORE notificationService.initialize().
      // So we should probably move this or ensure initialize is called.
      // But scheduleReminder doesn't STRICTLY need initialize() to be finished for the plugin to work if it's already setup.
      // Actually, better to do it after initialize in main.dart.
    }
  }

  static Future<void> reconcileReminders(List<Reminder> reminders) async {
    final notificationService = NotificationService();
    for (final r in reminders) {
      if (r.state != 'scheduling') continue;

      try {
        final success = await notificationService.scheduleReminder(
          id: r.notificationId,
          title: r.title,
          body: r.notificationBody,
          scheduledTime: r.scheduledAt,
          recurrence: r.recurrenceType,
          recurrenceRule: r.recurrenceRule,
        );

        if (success) {
          r.state = 'active';
          r.failureReason = null;
        } else {
          r.state = 'failed';
          r.failureReason = 'Failed to schedule during reconciliation';
        }
        await r.save();
      } catch (e) {
        r.state = 'failed';
        r.failureReason = e.toString();
        await r.save();
      }
    }
  }

  static Future<void> _reconcilePurchase(JobRecord job) async {
    final payload = job.payload;
    final plannedItemKey = payload['plannedItemKey'] as String;
    final productName = payload['productName'] as String;
    final amount = payload['amount'] as int;
    final dateStr = payload['date'] as String;
    final date = DateTime.parse(dateStr);

    final expensesBox = Hive.box<Expense>(FinanceBoxes.expensesBoxName);
    final futureExpensesBox = Hive.box<FutureExpense>(
      FinanceBoxes.futureExpensesBoxName,
    );

    // Look for a matching expense (same product name, amount, category, close date)
    Expense? matchingExpense;
    for (final exp in expensesBox.values) {
      if (exp.productName == productName &&
          exp.amount == amount &&
          exp.date.difference(date).abs().inMinutes < 5) {
        matchingExpense = exp;
        break;
      }
    }

    if (matchingExpense != null) {
      // Expense exists -> ensure FutureExpense is marked purchased
      FutureExpense? plannedItem;
      for (final item in futureExpensesBox.values) {
        if (item.id == plannedItemKey) {
          plannedItem = item;
          break;
        }
      }

      if (plannedItem != null) {
        plannedItem.isPurchased = true;
        plannedItem.linkedExpenseKey = matchingExpense.key as int?;
        plannedItem.purchasedAmount = amount;
        plannedItem.purchasedAt = matchingExpense.date;
        await plannedItem.save();
      }
      job.state = 'complete';
      await job.save();
    } else {
      // Expense does not exist -> mark job failed so user/app knows it was incomplete
      job.state = 'failed';
      await job.save();
    }
  }

  static Future<void> cleanupTempExports() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final now = DateTime.now();
        final files = tempDir.listSync();
        for (final entity in files) {
          if (entity is File && entity.path.contains('budgo_expenses_')) {
            final stat = entity.statSync();
            if (now.difference(stat.modified).inHours >= 24) {
              await entity.delete();
            }
          }
        }
      }
    } catch (_) {}
  }
}

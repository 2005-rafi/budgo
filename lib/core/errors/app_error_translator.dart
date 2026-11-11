import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import 'package:expense/core/constants/app_brand.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/currency/currency_formatter.dart';

enum FeedbackSeverity { success, info, warning, error }

/// Identifies the user-facing workflow so errors receive meaningful context
/// without hardcoding boilerplate phrases across widgets.
enum FeedbackOperation {
  saveTransaction('Could not save transaction'),
  deleteTransaction('Could not delete transaction'),
  confirmIncome('Could not confirm income'),
  purchaseWishlist('Could not mark item as purchased'),
  saveWishlist('Could not save wishlist item'),
  deleteWishlist('Could not delete wishlist item'),
  depositVault('Could not deposit to vault'),
  withdrawVault('Could not withdraw from vault'),
  saveVault('Could not save vault'),
  deleteVault('Could not delete vault'),
  selfTransfer('Transfer could not be completed'),
  settleCreditCard('Card settlement could not be completed'),
  createWorkspace('Could not create workspace'),
  renameWorkspace('Could not update workspace'),
  deleteWorkspace('Could not delete workspace'),
  saveCategory('Could not save category'),
  archiveCategory('Could not archive category'),
  saveBudget('Could not save budget'),
  clearBudget('Could not clear budget'),
  saveReminder('Could not schedule reminder'),
  deleteReminder('Could not delete reminder'),
  toggleReminder('Could not update reminder'),
  exportCsv('CSV export failed'),
  exportPdf('PDF export failed'),
  exportCancelled('Export cancelled'),
  resetData('Could not reset app data'),
  wipeWorkspace('Could not clear workspace data'),
  archiveData('Could not archive old data'),
  compactStorage('Could not compact storage'),
  openLink('Could not open link'),
  appStartup('Could not finish starting');

  final String failureTitle;
  const FeedbackOperation(this.failureTitle);

  String resolveFailureTitle() => this == FeedbackOperation.appStartup
      ? 'Could not finish starting ${AppBrand.appName}'
      : failureTitle;
}

class FeedbackMessage {
  final String title;
  final String? guidance;
  final FeedbackSeverity severity;

  const FeedbackMessage({
    required this.title,
    this.guidance,
    required this.severity,
  });

  /// Combined plain-text representation suitable for logging or screen readers.
  String get fullText => guidance != null && guidance!.isNotEmpty
      ? '$title\n$guidance'
      : title;
}

/// Centralized, dynamic translator turning domain, storage, format, and OS
/// exceptions into human-friendly explanations with actionable recovery steps.
class AppErrorTranslator {
  AppErrorTranslator._();

  static FeedbackMessage translate(
    Object? error, {
    FeedbackOperation? operation,
  }) {
    final opPrefix = operation?.resolveFailureTitle();

    if (error == null) {
      return FeedbackMessage(
        title: opPrefix ?? 'Something went wrong',
        guidance: 'Please try again. If this repeats, restart the app cleanly.',
        severity: FeedbackSeverity.error,
      );
    }

    // 1. Typed Domain Exceptions
    if (error is InsufficientFundsException) {
      final hasAmounts =
          error.availablePaise != null && error.requestedPaise != null;
      final accountLabel = error.accountName ?? 'the selected account';
      final title = hasAmounts
          ? 'Not enough funds in $accountLabel '
              '(Free: ${CurrencyFormatter.formatPaise(error.availablePaise!)}, '
              'Needed: ${CurrencyFormatter.formatPaise(error.requestedPaise!)})'
          : _sanitize(error.message);

      return FeedbackMessage(
        title: opPrefix != null && !title.toLowerCase().contains('not enough')
            ? '$opPrefix: $title'
            : title,
        guidance: error.guidance ??
            'Enter a smaller amount, add income, or choose a funded account.',
        severity: FeedbackSeverity.error,
      );
    }

    if (error is DuplicateEntityException) {
      final entity = error.entityType ?? 'Item';
      return FeedbackMessage(
        title: _sanitize(error.message),
        guidance: error.guidance ??
            'Choose a different $entity name to avoid duplicates.',
        severity: FeedbackSeverity.warning,
      );
    }

    if (error is LimitExceededException) {
      return FeedbackMessage(
        title: _sanitize(error.message),
        guidance: error.guidance ??
            'Remove or archive older entries before adding a new one.',
        severity: FeedbackSeverity.warning,
      );
    }

    if (error is PermissionException) {
      return FeedbackMessage(
        title: _sanitize(error.message),
        guidance: error.guidance ??
            'Enable the required permission in your device Settings and try again.',
        severity: FeedbackSeverity.error,
      );
    }

    if (error is ValidationException) {
      return FeedbackMessage(
        title: _sanitize(error.message),
        guidance: error.guidance,
        severity: FeedbackSeverity.warning,
      );
    }

    if (error is NotFoundException) {
      final entity = error.entityType ?? 'item';
      return FeedbackMessage(
        title: _sanitize(error.message),
        guidance: error.guidance ??
            'This $entity may have been deleted or moved. Refresh and try again.',
        severity: FeedbackSeverity.error,
      );
    }

    if (error is StorageException) {
      return FeedbackMessage(
        title: opPrefix ?? 'Could not save to device storage',
        guidance: error.guidance ??
            _extractSafeReasonOrDefault(
              error.reason ?? error.message,
              'Your device storage may be full or temporarily locked. Free up a little space and retry.',
            ),
        severity: FeedbackSeverity.error,
      );
    }

    if (error is AppException) {
      return FeedbackMessage(
        title: _sanitize(error.message),
        guidance: error.guidance ?? error.reason,
        severity: FeedbackSeverity.error,
      );
    }

    // 2. Native Dart / OS / Platform Exceptions (never expose raw stack/errno!)
    if (error is FileSystemException) {
      final osMsg = (error.osError?.message ?? error.message).toLowerCase();
      if (osMsg.contains('space') || osMsg.contains('no space left')) {
        return FeedbackMessage(
          title: opPrefix ?? 'Device storage is full',
          guidance:
              'Free up storage space on your device before exporting or saving.',
          severity: FeedbackSeverity.error,
        );
      }
      if (osMsg.contains('permission') || osMsg.contains('denied')) {
        return FeedbackMessage(
          title: opPrefix ?? 'Storage permission denied',
          guidance:
              'Allow file/storage access in your device Settings and try again.',
          severity: FeedbackSeverity.error,
        );
      }
      return FeedbackMessage(
        title: opPrefix ?? 'Could not access device file',
        guidance:
            'Make sure the target folder is accessible and storage is not full.',
        severity: FeedbackSeverity.error,
      );
    }

    if (error is FormatException) {
      return FeedbackMessage(
        title: 'Invalid number or date format',
        guidance: 'Enter valid numbers using up to 2 decimal places.',
        severity: FeedbackSeverity.warning,
      );
    }

    if (error is TimeoutException) {
      return FeedbackMessage(
        title: opPrefix ?? 'Operation timed out',
        guidance: 'Your device was busy completing the request. Please try again.',
        severity: FeedbackSeverity.error,
      );
    }

    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      if (code.contains('alarm') || code.contains('permission')) {
        return FeedbackMessage(
          title: 'Notification or alarm permission required',
          guidance:
              'Allow Notifications and Alarms & Reminders for ${AppBrand.appName} in system Settings.',
          severity: FeedbackSeverity.error,
        );
      }
      return FeedbackMessage(
        title: opPrefix ?? 'System action could not complete',
        guidance: 'Please check system permissions or try again.',
        severity: FeedbackSeverity.error,
      );
    }

    if (error is HiveError) {
      return FeedbackMessage(
        title: opPrefix ?? 'Local database temporarily unavailable',
        guidance:
            'Restart the app if your recent change did not appear; existing data remains safe.',
        severity: FeedbackSeverity.error,
      );
    }

    if (error is StateError || error is RangeError || error is ArgumentError) {
      return FeedbackMessage(
        title: opPrefix ?? 'Action could not be completed',
        guidance:
            'The selected record may be missing or out of date. Re-open the screen and try again.',
        severity: FeedbackSeverity.error,
      );
    }

    // 3. String / Generic fallback (sanitized against developer traces)
    final raw = error.toString();
    final cleaned = _sanitize(raw);

    if (_looksTechnical(raw)) {
      return FeedbackMessage(
        title: opPrefix ?? 'Unexpected issue occurred',
        guidance:
            'Please try again. Restart the app if this keeps happening.',
        severity: FeedbackSeverity.error,
      );
    }

    return FeedbackMessage(
      title: cleaned.isNotEmpty
          ? cleaned
          : (opPrefix ?? 'Action could not be completed'),
      severity: FeedbackSeverity.error,
    );
  }

  static String _extractSafeReasonOrDefault(String candidate, String fallback) {
    if (_looksTechnical(candidate)) return fallback;
    final clean = _sanitize(candidate);
    return clean.isEmpty ? fallback : clean;
  }

  static bool _looksTechnical(String text) {
    final lower = text.toLowerCase();
    return lower.contains('instance of ') ||
        lower.contains('hiveerror') ||
        lower.contains('nosuchmethoderror') ||
        lower.contains('type \'') ||
        lower.contains('subtype of type') ||
        lower.contains('errno =') ||
        lower.contains('stacktrace') ||
        lower.contains('package:expense/') ||
        lower.contains('acc_') ||
        lower.contains('ws_') ||
        lower.contains('trf_') ||
        lower.contains('failed to ');
  }

  static String _sanitize(String raw) {
    var msg = raw.trim();
    const prefixes = [
      'Exception: ',
      'AppException: ',
      'StorageException: ',
      'ValidationException: ',
      'InsufficientFundsException: ',
      'NotFoundException: ',
      'DuplicateEntityException: ',
      'LimitExceededException: ',
      'PermissionException: ',
      'FormatException: ',
    ];
    for (final prefix in prefixes) {
      if (msg.startsWith(prefix)) {
        msg = msg.substring(prefix.length).trim();
      }
    }
    // Never leak internal UUIDs or IDs like acc_default_bank
    msg = msg.replaceAll(RegExp(r'\b(acc|ws|trf|v)_[a-zA-Z0-9_-]+\b'), 'account');
    return msg;
  }
}


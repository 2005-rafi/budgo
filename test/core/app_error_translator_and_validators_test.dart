import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:expense/core/errors/app_error_translator.dart';
import 'package:expense/core/errors/app_exception.dart';
import 'package:expense/core/utils/input_validators.dart';

void main() {
  group('AppErrorTranslator Tests', () {
    test('Translates InsufficientFundsException dynamically with formatted balances and guidance', () {
      final err = InsufficientFundsException(
        'Insufficient funds',
        availablePaise: 50000,
        requestedPaise: 100000,
        accountName: 'Bank & UPI pool',
        alternativeHint: 'Your Cash Wallet holds ₹2,000.00. Transfer funds first.',
      );

      final msg = AppErrorTranslator.translate(err, operation: FeedbackOperation.depositVault);

      expect(msg.title, contains('Bank & UPI pool'));
      expect(msg.title, contains('Free: ₹500.00'));
      expect(msg.title, contains('Needed: ₹1,000.00'));
      expect(msg.guidance, contains('Cash Wallet'));
      expect(msg.severity, FeedbackSeverity.error);
    });

    test('Translates DuplicateEntityException and LimitExceededException with warning severity', () {
      final dup = DuplicateEntityException('A category named "Food" already exists.', entityType: 'category');
      final dupMsg = AppErrorTranslator.translate(dup, operation: FeedbackOperation.saveCategory);
      expect(dupMsg.title, contains('Food'));
      expect(dupMsg.guidance, contains('category'));
      expect(dupMsg.severity, FeedbackSeverity.warning);

      final limit = LimitExceededException(
        'Maximum of 12 active categories reached.',
        maxLimit: 12,
        guidance: 'Archive an unused category first.',
      );
      final limitMsg = AppErrorTranslator.translate(limit);
      expect(limitMsg.title, contains('12'));
      expect(limitMsg.guidance, contains('Archive'));
      expect(limitMsg.severity, FeedbackSeverity.warning);
    });

    test('Masks StorageException and HiveError technical internals cleanly', () {
      final storageErr = StorageException('Failed to read expenses: HiveError: Box not found at /data/user/0/acc_1234');
      final storageMsg = AppErrorTranslator.translate(storageErr, operation: FeedbackOperation.saveTransaction);
      expect(storageMsg.title, 'Could not save transaction');
      expect(storageMsg.title, isNot(contains('HiveError')));
      expect(storageMsg.guidance, isNot(contains('HiveError')));
      expect(storageMsg.guidance, isNot(contains('acc_1234')));

      final hiveErr = HiveError('Box closed prematurely');
      final hiveMsg = AppErrorTranslator.translate(hiveErr);
      expect(hiveMsg.title, isNot(contains('Box closed prematurely')));
      expect(hiveMsg.guidance, contains('Restart the app'));
    });

    test('Translates OS FileSystemException, FormatException, PlatformException, TimeoutException', () {
      final fullDisk = const FileSystemException('Write failed', '/tmp/report.pdf', OSError('No space left on device', 28));
      final diskMsg = AppErrorTranslator.translate(fullDisk, operation: FeedbackOperation.exportPdf);
      expect(diskMsg.title, contains('PDF export failed'));
      expect(diskMsg.guidance, contains('Free up storage space'));

      final permErr = PlatformException(code: 'exact_alarms_not_permitted', message: 'SecurityException');
      final permMsg = AppErrorTranslator.translate(permErr);
      expect(permMsg.title, contains('Notification or alarm permission'));
      expect(permMsg.guidance, contains('Settings'));

      final formatMsg = AppErrorTranslator.translate(const FormatException('Bad double'));
      expect(formatMsg.title, contains('Invalid number'));

      final timeoutMsg = AppErrorTranslator.translate(TimeoutException('timed out'), operation: FeedbackOperation.exportCsv);
      expect(timeoutMsg.title, contains('CSV export failed'));
      expect(timeoutMsg.guidance, contains('busy'));
    });

    test('Sanitizes unexpected developer objects and strips internal IDs', () {
      final raw = Exception('Unhandled StorageException: Null check operator on acc_default_bank');
      final msg = AppErrorTranslator.translate(raw, operation: FeedbackOperation.selfTransfer);
      expect(msg.title, isNot(contains('Exception:')));
      expect(msg.title, isNot(contains('acc_default_bank')));

      final uglyType = StateError('Bad state: No element in ws_123456');
      final stateMsg = AppErrorTranslator.translate(uglyType, operation: FeedbackOperation.depositVault);
      expect(stateMsg.title, 'Could not deposit to vault');
      expect(stateMsg.guidance, isNot(contains('ws_123456')));
    });
  });

  group('InputValidators Tests', () {
    test('validateAmount rejects empty, negative, >2 decimals, and ceiling overflow', () {
      expect(InputValidators.validateAmount('').isValid, isFalse);
      expect(InputValidators.validateAmount('-50').isValid, isFalse);
      expect(InputValidators.validateAmount('0').isValid, isFalse);
      expect(InputValidators.validateAmount('12.345').errorMessage, contains('2 decimal places'));
      expect(InputValidators.validateAmount('20000000').errorMessage, contains('cannot exceed'));

      final ok = InputValidators.validateAmount('250.50');
      expect(ok.isValid, isTrue);
      expect(ok.paise, 25050);
    });

    test('validateAmount enforces maxPaiseLimit cleanly', () {
      final over = InputValidators.validateAmount(
        '600',
        maxPaiseLimit: 50000,
        maxPaiseLimitLabel: 'vault balance',
      );
      expect(over.isValid, isFalse);
      expect(over.errorMessage, contains('vault balance'));
      expect(over.errorMessage, contains('₹500.00'));
    });
  });
}


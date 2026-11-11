import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:expense/models/expense.dart';
import 'package:expense/models/income.dart';
import 'package:expense/models/budget.dart';
import 'package:expense/models/future_expense.dart';

class TestBinaryReader implements BinaryReader {
  final Map<int, dynamic> fields;
  final List<dynamic> _stream = [];
  int _ptr = 0;

  TestBinaryReader(this.fields) {
    _stream.add(fields.length); // numOfFields
    for (final entry in fields.entries) {
      _stream.add(entry.key); // field index
      _stream.add(entry.value); // field value
    }
  }

  @override
  int readByte() {
    return _stream[_ptr++] as int;
  }

  @override
  dynamic read([int? typeId]) {
    return _stream[_ptr++];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Resilient Adapters Test', () {
    test('ExpenseAdapter deserializes double amounts without casting error', () {
      final adapter = ExpenseAdapter();
      final reader = TestBinaryReader({
        0: 'Coffee',
        1: 150.50, // double amount (legacy schema simulation)
        2: 'Food',
        3: DateTime(2026, 5, 1),
        4: false,
        5: 'UPI',
      });

      final expense = adapter.read(reader);

      expect(expense.productName, 'Coffee');
      expect(expense.amount, 151); // 150.50 rounded to int paise
      expect(expense.category, 'Food');
      expect(expense.paymentMethod, 'UPI');
    });

    test('IncomeAdapter deserializes double amounts safely', () {
      final adapter = IncomeAdapter();
      final reader = TestBinaryReader({
        0: 'inc_1',
        1: 'Salary',
        2: 50000.75, // double amount
        3: DateTime(2026, 5, 1),
        4: 'Monthly',
        5: true,
      });

      final income = adapter.read(reader);

      expect(income.id, 'inc_1');
      expect(income.amount, 50001);
      expect(income.source, 'Salary');
      expect(income.isConfirmed, true);
    });

    test('BudgetAdapter deserializes double limits safely', () {
      final adapter = BudgetAdapter();
      final reader = TestBinaryReader({
        0: 'b_1',
        1: 25000.0, // double limit
        2: 'monthly',
        3: DateTime(2026, 5, 1),
        4: DateTime(2026, 5, 31),
        5: true,
        6: 0.85,
      });

      final budget = adapter.read(reader);

      expect(budget.id, 'b_1');
      expect(budget.limit, 25000);
      expect(budget.warningThreshold, 0.85);
    });

    test('FutureExpenseAdapter deserializes double estimatedCost and purchasedAmount safely', () {
      final adapter = FutureExpenseAdapter();
      final reader = TestBinaryReader({
        0: 'fut_1',
        1: 'Headphones',
        2: 3500.50, // double estimatedCost
        3: 2, // priority
        4: DateTime(2026, 6, 1),
        5: true,
        6: 'Shopping',
        7: 'Sony',
        8: 42, // linkedExpenseKey
        9: 3499.0, // double purchasedAmount
        10: DateTime(2026, 5, 15),
      });

      final item = adapter.read(reader);

      expect(item.id, 'fut_1');
      expect(item.estimatedCost, 3501);
      expect(item.priority, 2);
      expect(item.linkedExpenseKey, 42);
      expect(item.purchasedAmount, 3499);
    });
  });
}

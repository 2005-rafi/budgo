import 'package:expense/models/expense.dart';
import 'package:expense/provider/expenses_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  static const List<String> _categories = <String>[
    'Food',
    'Travel',
    'Bills',
    'Shopping',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _productController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // Only used if category == "Other"
  final TextEditingController _customCategoryController =
      TextEditingController();

  String _selectedCategory = _categories.first;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _productController.dispose();
    _amountController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  bool get _isOtherSelected => _selectedCategory == 'Other';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitExpense() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final category = _isOtherSelected
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    final expense = Expense(
      productName: _productController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      category: category,
      date: _selectedDate,
    );

    // Preferred (centralized): Provider -> Hive handled inside provider
    await context.read<ExpensesProvider>().addExpense(expense);

    // If you still use Hive directly here, use this instead:
    // await Hive.box<Expense>('expenses').add(expense);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Expense"),
        backgroundColor: color.primary,
        foregroundColor: color.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Expense Details",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Product Name
              TextFormField(
                controller: _productController,
                style: TextStyle(color: color.onSurface),
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.shopping_cart_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a product name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: color.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),

                  // Key part: apply onSurface colors
                  labelStyle: TextStyle(color: color.onSurface),
                  hintStyle: TextStyle(color: color.onSurfaceVariant),
                  prefixIconColor: color.onSurfaceVariant,

                  // Optional: make border match theme
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color.primary, width: 2),
                  ),
                ),
                dropdownColor:
                    color.surface, // optional for the opened menu background
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: TextStyle(color: color.onSurface),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCategory = value;
                    if (!_isOtherSelected) _customCategoryController.clear();
                  });
                },
              ),

              // Custom category input (only if Other selected)
              if (_isOtherSelected) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customCategoryController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: color.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Custom category',
                    hintText: 'e.g., Health, Education, Fuel',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.edit_outlined),
                    labelStyle: TextStyle(color: color.onSurface),
                    hintStyle: TextStyle(color: color.onSurfaceVariant),
                    prefixIconColor: color.onSurfaceVariant,
                  ),
                  validator: (v) {
                    if (!_isOtherSelected) return null;
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Enter a category name';
                    if (t.length < 2) return 'Category is too short';
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: const OutlineInputBorder(),

                    prefixIcon: const Icon(Icons.calendar_today),
                    labelStyle: TextStyle(color: color.onSurface),
                    hintStyle: TextStyle(color: color.onSurfaceVariant),
                    prefixIconColor: color.onSurfaceVariant,
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: TextStyle(color: color.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _submitExpense,
                icon: const Icon(Icons.save),
                label: const Text("Save Expense"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.secondary,
                  foregroundColor: color.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel"),
                style: TextButton.styleFrom(foregroundColor: color.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

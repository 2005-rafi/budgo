import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense/provider/reminder_provider.dart';
import 'package:expense/widgets/forms/reminders_management_sheet.dart';

class ReminderActionBadge extends StatelessWidget {
  const ReminderActionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider>();
    final activeCount = provider.items
        .where((r) => r.isActive && r.state == 'active')
        .length;

    return IconButton(
      icon: Badge(
        label: Text('$activeCount'),
        isLabelVisible: activeCount > 0,
        child: const Icon(Icons.notifications_active_outlined),
      ),
      tooltip: 'Bill Reminders',
      onPressed: () => RemindersManagementSheet.show(context),
    );
  }
}

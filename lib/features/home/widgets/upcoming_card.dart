import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';

class UpcomingCard extends StatelessWidget {
  final List<LifeItem> items;
  const UpcomingCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('即将到期', style: Theme.of(context).textTheme.titleMedium),
                if (items.isNotEmpty)
                  TextButton(onPressed: () => context.push('/items'), child: const Text('查看全部')),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('未来7天没有到期事项', style: Theme.of(context).textTheme.bodyMedium)),
              )
            else
              ...items.take(5).map((item) {
                final days = DateFormatter.daysRemaining(item.dueTime);
                final color = days <= 1 ? AppColors.overdue : days <= 3 ? AppColors.upcoming : AppColors.primary;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.title),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(DateFormatter.formatRelative(item.dueTime), style: TextStyle(color: color, fontSize: 12)),
                  ),
                  onTap: () => context.push('/items/${item.id}'),
                );
              }),
          ],
        ),
      ),
    );
  }
}

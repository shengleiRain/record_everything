import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../life_item/widgets/life_item_detail_sheet.dart';

class TodayTodosCard extends ConsumerWidget {
  final List<LifeItem> items;
  const TodayTodosCard({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('今日待办', style: Theme.of(context).textTheme.titleMedium),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () => context.push('/items'),
                    child: const Text('查看全部'),
                  ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '今天没有待办事项',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...items
                  .take(3)
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.check_circle_outline, size: 20),
                      title: Text(item.title),
                      subtitle: Text(
                        DateFormatter.formatRelative(item.dueTime),
                      ),
                      onTap: () => showLifeItemDetailSheet(context, ref, item),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

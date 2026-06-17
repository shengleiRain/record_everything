import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../data/database/app_database.dart';
import '../providers/project_providers.dart';

class ProjectTimeline extends ConsumerWidget {
  const ProjectTimeline({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(projectEventsProvider(projectId));
    final itemsAsync = ref.watch(projectLifeItemsProvider(projectId));
    final billsAsync = ref.watch(projectBillsProvider(projectId));

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
      data: (events) => itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('加载失败: $e'),
        data: (items) => billsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载失败: $e'),
          data: (bills) {
            final entries = _mergeTimeline(events, items, bills);
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '暂无时间线记录',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) =>
                  _TimelineEntry(entry: entries[index]),
            );
          },
        ),
      ),
    );
  }

  List<_TimelineEntryData> _mergeTimeline(
    List<ProjectEvent> events,
    List<LifeItem> items,
    List<BillRecord> bills,
  ) {
    final List<_TimelineEntryData> result = [];

    for (final e in events) {
      result.add(
        _TimelineEntryData(
          time: e.eventTime,
          title: e.title,
          subtitle: e.description,
          icon: _iconForEventType(e.eventType),
          color: _colorForEventType(e.eventType),
        ),
      );
    }

    // Only show bill-like items that are not linked to a bill record.
    final linkedLifeItemIds = bills
        .where((b) => b.lifeItemId != null)
        .map((b) => b.lifeItemId!)
        .toSet();

    for (final item in items) {
      final hasAmount =
          item.amountType == 'income' || item.amountType == 'expense';
      if (hasAmount && linkedLifeItemIds.contains(item.id)) {
        continue; // Will be shown via the bill
      }
      result.add(
        _TimelineEntryData(
          time: item.dueTime,
          title: item.title,
          subtitle: item.status == 'completed' ? '已完成' : null,
          icon: hasAmount ? Icons.schedule_outlined : Icons.event_note_outlined,
          color: hasAmount ? Colors.orange : Colors.blueGrey,
        ),
      );
    }

    for (final b in bills) {
      final prefix = b.amountType == 'income' ? '收入' : '支出';
      result.add(
        _TimelineEntryData(
          time: b.billTime,
          title: '$prefix: ${b.title}',
          subtitle: MoneyFormatter.formatInt(b.amount),
          icon: b.amountType == 'income'
              ? Icons.arrow_downward
              : Icons.arrow_upward,
          color: b.amountType == 'income' ? Colors.green : Colors.red,
        ),
      );
    }

    result.sort((a, b) => b.time.compareTo(a.time));
    return result;
  }

  IconData _iconForEventType(String type) => switch (type) {
    'status_change' => Icons.swap_horiz,
    'communication' => Icons.chat_bubble_outline,
    'milestone' => Icons.flag_outlined,
    'delivery' => Icons.local_shipping_outlined,
    _ => Icons.note_outlined,
  };

  Color _colorForEventType(String type) => switch (type) {
    'status_change' => Colors.blue,
    'communication' => Colors.purple,
    'milestone' => Colors.amber,
    'delivery' => Colors.teal,
    _ => Colors.grey,
  };
}

class _TimelineEntryData {
  final DateTime time;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _TimelineEntryData({
    required this.time,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry});

  final _TimelineEntryData entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, size: 16, color: entry.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (entry.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  DateFormatter.formatDateTime(entry.time),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

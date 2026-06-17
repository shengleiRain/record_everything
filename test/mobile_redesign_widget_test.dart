import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/features/bill/widgets/bill_day_group.dart';
import 'package:record_everything/features/bill/widgets/month_summary_card.dart';
import 'package:record_everything/features/home/models/agenda_item_view_model.dart';
import 'package:record_everything/features/home/models/day_bucket_view_model.dart';
import 'package:record_everything/features/home/widgets/home_calendar.dart';
import 'package:record_everything/features/home/widgets/home_calendar_sliver.dart';
import 'package:record_everything/features/home/widgets/home_summary_strip.dart';
import 'package:record_everything/features/home/widgets/quick_create_sheet.dart';
import 'package:record_everything/features/home/widgets/selected_day_agenda.dart';
import 'package:record_everything/features/life_item/widgets/life_item_card.dart';
import 'package:record_everything/core/widgets/sheet_action_layout.dart';

void main() {
  testWidgets('home calendar renders controls and handles taps', (
    tester,
  ) async {
    var previousTapped = false;
    var nextTapped = false;
    DateTime? selectedDate;

    await tester.pumpWidget(
      _Harness(
        child: HomeCalendar(
          isWeek: true,
          visibleAnchorDate: DateTime(2026, 6, 4),
          visibleBuckets: _weekBuckets(DateTime(2026, 6, 4)),
          onPrevious: () => previousTapped = true,
          onNext: () => nextTapped = true,
          onSelectDate: (date) => selectedDate = date,
        ),
      ),
    );

    expect(find.text('周日'), findsOneWidget);
    expect(find.text('周六'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-calendar-previous')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-calendar-next')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-calendar-previous')));
    await tester.tap(find.byKey(const ValueKey('home-calendar-next')));
    await tester.tap(find.byKey(const ValueKey('home-calendar-day-2026-6-4')));

    expect(previousTapped, isTrue);
    expect(nextTapped, isTrue);
    expect(selectedDate, DateTime(2026, 6, 4));
  });

  testWidgets('selected day agenda only renders supplied selected-day items', (
    tester,
  ) async {
    final lifeItem = _lifeItem(
      id: 1,
      title: '选中日事项',
      amount: 1200,
      amountType: 'expense',
    );
    final billRecord = _billRecord(
      id: 2,
      title: '选中日账单',
      amount: 800,
      amountType: 'expense',
    );

    await tester.pumpWidget(
      _Harness(
        child: SelectedDayAgenda(
          selectedDate: DateTime(2026, 6, 4),
          items: [
            AgendaItemViewModel(
              id: 1,
              kind: AgendaItemKind.lifeItem,
              title: '选中日事项',
              subtitle: '账单事项',
              date: DateTime(2026, 6, 4),
              amount: 1200,
              amountType: 'expense',
              status: '待处理',
              isCompleted: false,
              isOverdue: false,
              lifeItem: lifeItem,
            ),
            AgendaItemViewModel(
              id: 2,
              kind: AgendaItemKind.billRecord,
              title: '选中日账单',
              subtitle: '账单',
              date: DateTime(2026, 6, 4),
              amount: 800,
              amountType: 'expense',
              status: '已记录',
              isCompleted: true,
              isOverdue: false,
              billRecord: billRecord,
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('selected-day-agenda')), findsOneWidget);
    expect(find.text('选中日事项'), findsOneWidget);
    expect(find.text('选中日账单'), findsOneWidget);

    await tester.tap(find.text('选中日事项'));
    await tester.pumpAndSettle();
    expect(find.text('到期时间'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选中日账单'));
    await tester.pumpAndSettle();
    expect(find.text('记账时间'), findsOneWidget);
  });

  testWidgets('home calendar sliver paints opaque background behind gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: CalendarSliver(
                summaryStrip: const HomeSummaryStrip(
                  monthlyExpense: 0,
                  monthlyIncome: 0,
                  pendingCount: 0,
                  overdueCount: 0,
                ),
                visibleAnchorDate: DateTime(2026, 6, 4),
                selectedDate: DateTime(2026, 6, 4),
                monthBuckets: _weekBuckets(DateTime(2026, 6, 4)),
                onPrevious: () {},
                onNext: () {},
                onSelectDate: (_) {},
                screenWidth: 390,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 600)),
          ],
        ),
      ),
    );

    final background = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('home-calendar-surface')),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(background.color, const Color(0xFFF8FAF9));
  });

  testWidgets('quick create sheet exposes mobile creation actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(child: QuickCreateSheet(onNavigate: (_, {extra}) {})),
    );

    expect(find.byKey(const ValueKey('quick-create-bill')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-create-item')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-create-bill-item')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('quick-create-template')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-create-project')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-create-photography')),
      findsOneWidget,
    );
  });

  testWidgets('life item card keeps dense row information and action menu', (
    tester,
  ) async {
    var completed = false;
    var deferred = false;

    await tester.pumpWidget(
      _Harness(
        child: LifeItemCard(
          item: _lifeItem(
            id: 7,
            title: '会员续费',
            amount: 1999,
            amountType: 'expense',
            repeatRule: 'monthly',
          ),
          onComplete: () => completed = true,
          onDefer: () => deferred = true,
        ),
      ),
    );

    expect(find.text('会员续费'), findsOneWidget);
    expect(find.textContaining('重复'), findsOneWidget);
    expect(find.text('¥19.99'), findsOneWidget);

    // Reveal swipe actions by dragging the card leftward.
    await tester.drag(find.text('会员续费'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('延期'));
    await tester.pumpAndSettle();
    expect(deferred, isTrue);

    await tester.drag(find.text('会员续费'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets(
    'life item card avoids duplicate date and redundant status copy',
    (tester) async {
      await tester.pumpWidget(
        _Harness(
          child: Column(
            children: [
              LifeItemCard(
                item: _lifeItem(
                  id: 8,
                  title: '远期事项',
                  dueTime: DateTime(2026, 6, 25),
                ),
              ),
              LifeItemCard(
                item: _lifeItem(
                  id: 9,
                  title: '完成事项',
                  status: 'completed',
                  updatedAt: DateTime(2026, 6, 15, 8, 46),
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.textContaining('2026-06-25 · 06-25'), findsNothing);
      expect(find.text('2026-06-25'), findsOneWidget);
      expect(find.textContaining('完成于'), findsNothing);
      expect(find.text('2026-06-15 08:46'), findsOneWidget);
    },
  );

  testWidgets('sheet action layout adapts symmetrically by action count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        child: SizedBox(
          width: 320,
          child: SheetActionLayout(
            children: [
              FilledButton(
                key: const ValueKey('sheet-primary-action'),
                onPressed: () {},
                child: const Text('主操作'),
              ),
              OutlinedButton(
                key: const ValueKey('sheet-secondary-action'),
                onPressed: () {},
                child: const Text('次操作'),
              ),
              OutlinedButton(
                key: const ValueKey('sheet-delete-action'),
                onPressed: () {},
                child: const Text('删除'),
              ),
            ],
          ),
        ),
      ),
    );

    final primary = tester.getSize(
      find.byKey(const ValueKey('sheet-primary-action')),
    );
    final secondary = tester.getSize(
      find.byKey(const ValueKey('sheet-secondary-action')),
    );
    final delete = tester.getSize(
      find.byKey(const ValueKey('sheet-delete-action')),
    );

    expect(primary.width, greaterThan(secondary.width));
    expect(secondary.width, delete.width);
  });

  testWidgets('bill summary and day group render compact monthly information', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        child: ListView(
          children: [
            const MonthSummaryCard(income: 900000, expense: 12345),
            BillDayGroup(
              date: DateTime(2026, 6, 4),
              bills: [
                _billRecord(
                  id: 1,
                  title: '早餐',
                  amount: 1200,
                  amountType: 'expense',
                ),
                _billRecord(
                  id: 2,
                  title: '工资',
                  amount: 900000,
                  amountType: 'income',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.textContaining('结余'), findsOneWidget);
    expect(find.text('6月4日 周四'), findsOneWidget);
    expect(find.text('2笔 · +¥8988.00'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('工资'), findsOneWidget);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }
}

List<DayBucketViewModel> _weekBuckets(DateTime selected) {
  return List.generate(7, (index) {
    final date = DateTime(2026, 5, 31 + index);
    return DayBucketViewModel(
      date: date,
      isSelected: date == selected,
      isInVisibleMonth: date.month == 6,
      itemCount: index == 4 ? 2 : 0,
      overdueCount: 0,
      income: 0,
      expense: index == 4 ? 1200 : 0,
    );
  });
}

LifeItem _lifeItem({
  required int id,
  required String title,
  int? amount,
  String amountType = 'none',
  String? repeatRule,
  DateTime? dueTime,
  DateTime? updatedAt,
  String status = 'pending',
}) {
  final now = DateTime(2026, 6, 4, 9);
  return LifeItem(
    id: id,
    title: title,
    itemType: 'bill',
    amount: amount,
    amountType: amountType,
    dueTime: dueTime ?? now,
    repeatRule: repeatRule,
    status: status,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}

BillRecord _billRecord({
  required int id,
  required String title,
  required int amount,
  required String amountType,
}) {
  final now = DateTime(2026, 6, 4, 9);
  return BillRecord(
    id: id,
    title: title,
    amount: amount,
    amountType: amountType,
    billTime: now,
    createdAt: now,
    updatedAt: now,
  );
}

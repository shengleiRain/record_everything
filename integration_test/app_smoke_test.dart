import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:record_everything/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main Android business paths work across all pages', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.text('今天有什么要处理？'), findsOneWidget);

    final unique = DateTime.now().millisecondsSinceEpoch;
    final itemTitle = '自动事项 $unique';
    final editedItemTitle = '$itemTitle 已编辑';
    final templateExpirationTitle = '证件到期';
    final templateIncomeTitle = '工资收入';
    final recurringTitle = '自动重复事项 $unique';
    final customRecurringTitle = '自动自定义重复 $unique';
    final recurringNextTitle = '自动生成下一轮 $unique';
    final recurringBillNextTitle = '自动账单下一轮 $unique';
    final billableItemTitle = '自动记账事项 $unique';
    final listBillableItemTitle = '列表记账事项 $unique';
    final deleteItemTitle = '自动删除事项 $unique';
    final deferItemTitle = '自动延期事项 $unique';
    final categoryDateItemTitle = '自动分类日期事项 $unique';
    final billTitle = '自动账单 $unique';
    final editedBillTitle = '$billTitle 已编辑';
    final incomeBillTitle = '自动收入账单 $unique';
    final deleteBillTitle = '自动删除账单 $unique';

    await _openTab(tester, '事项');
    expect(find.text('生活事项'), findsOneWidget);

    await _createPlainItem(tester, itemTitle);
    await _openItemDetail(tester, itemTitle);
    expect(find.text('事项详情'), findsOneWidget);
    expect(find.text(itemTitle), findsOneWidget);

    await _tapIcon(tester, Icons.edit);
    await _pumpUntilFound(tester, find.text('编辑事项'));
    await tester.enterText(find.byType(TextFormField).first, editedItemTitle);
    await _tapText(tester, '保存修改');
    await _pumpUntilFound(tester, find.text(editedItemTitle));

    await _tapText(tester, '完成');
    await _pumpUntilFound(tester, find.text('仅完成'));
    await _tapText(tester, '仅完成');
    await _pumpUntilFound(tester, find.text('生活事项'));
    expect(find.text(editedItemTitle), findsOneWidget);

    await _createTemplateItem(tester, templateExpirationTitle);
    await _openItemDetail(tester, templateExpirationTitle);
    expect(find.text('到期提醒'), findsOneWidget);
    await _tapBack(tester);
    await _pumpUntilFound(tester, find.text('生活事项'));

    await _createTemplateItem(tester, templateIncomeTitle);
    await _openItemDetail(tester, templateIncomeTitle);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('每月'), findsOneWidget);
    await _tapBack(tester);
    await _pumpUntilFound(tester, find.text('生活事项'));

    await _createRecurringItem(tester, recurringTitle);
    await _openItemDetail(tester, recurringTitle);
    expect(find.text('每周'), findsOneWidget);
    await _tapBack(tester);
    await _pumpUntilFound(tester, find.text('生活事项'));

    await _createCustomRecurringItem(tester, customRecurringTitle);
    await _openItemDetail(tester, customRecurringTitle);
    expect(find.text('每 45 天'), findsOneWidget);
    await _tapBack(tester);
    await _pumpUntilFound(tester, find.text('生活事项'));

    await _createCategoryAndDateItem(tester, categoryDateItemTitle);
    await _openItemDetail(tester, categoryDateItemTitle);
    expect(find.text('普通待办'), findsOneWidget);
    await _tapBack(tester);
    await _pumpUntilFound(tester, find.text('生活事项'));

    await _createPlainItem(tester, deferItemTitle);
    await _tapCardActionForTitle(tester, deferItemTitle, '延期');
    await _confirmDatePicker(tester);
    await _pumpUntilFound(tester, find.text('生活事项'));

    await _createRecurringItem(tester, recurringNextTitle);
    await _tapCardActionForTitle(tester, recurringNextTitle, '完成');
    await _pumpUntilFound(tester, find.text('完成并生成下一轮'));
    await _tapText(tester, '完成并生成下一轮');
    await _pumpUntilFound(tester, find.text('生活事项'));
    expect(find.text('完成并生成下一轮'), findsNothing);

    await _createPlainItem(tester, deleteItemTitle);
    await _openItemDetail(tester, deleteItemTitle);
    await _tapIcon(tester, Icons.delete);
    await _pumpUntilFound(tester, find.text('确认删除'));
    await _tapText(tester, '删除');
    await _pumpUntilFound(tester, find.text('生活事项'));
    expect(find.text(deleteItemTitle), findsNothing);

    await _createBillableItemAndRecordBill(tester, billableItemTitle);
    await _createBillableItemAndRecordBillFromList(
      tester,
      listBillableItemTitle,
    );
    await _createRecurringBillItemAndGenerateNext(
      tester,
      recurringBillNextTitle,
    );
    await _coverAllTemplates(tester, unique);

    await _openTab(tester, '账单');
    expect(find.text('账单'), findsWidgets);
    await _pumpUntilFound(tester, find.text(billableItemTitle));
    expect(find.text('-¥23.45'), findsWidgets);
    await _pumpUntilFound(tester, find.text(listBillableItemTitle));
    expect(find.text('-¥34.56'), findsWidgets);
    await _pumpUntilFound(tester, find.text(recurringBillNextTitle));
    expect(find.text('-¥45.67'), findsWidgets);

    await _createBill(
      tester,
      title: billTitle,
      amount: '12.34',
      category: '餐饮',
      pickDate: true,
    );
    expect(find.text('-¥12.34'), findsWidgets);

    await _tapText(tester, billTitle);
    await _pumpUntilFound(tester, find.text('编辑账单'));
    await tester.enterText(find.byType(TextFormField).at(0), editedBillTitle);
    await _tapText(tester, '保存修改');
    await _pumpUntilFound(tester, find.text(editedBillTitle));

    await _createBill(
      tester,
      title: incomeBillTitle,
      amount: '100',
      amountType: '收入',
      category: '工资',
    );
    expect(find.text('+¥100.00'), findsWidgets);

    await _createBill(tester, title: deleteBillTitle, amount: '1.00');
    await _tapText(tester, deleteBillTitle);
    await _pumpUntilFound(tester, find.text('编辑账单'));
    await _tapIcon(tester, Icons.delete);
    await _pumpUntilFound(tester, find.text('确认删除'));
    await _tapText(tester, '删除');
    await tester.pumpAndSettle();
    expect(find.text(deleteBillTitle), findsNothing);
    await _tapIcon(tester, Icons.chevron_left);
    await _pumpUntilFound(tester, find.text('本月还没有账单'));
    await _tapIcon(tester, Icons.chevron_right);
    await _pumpUntilFound(tester, find.text('账单'));

    await _openTab(tester, '统计');
    expect(find.text('统计'), findsWidgets);
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('事项统计'), findsOneWidget);

    await _openTab(tester, '设置');
    expect(find.text('设置'), findsWidgets);
    expect(find.text('通知权限'), findsOneWidget);
    await _tapText(tester, '导入数据');
    await _pumpUntilFound(tester, find.text('导入数据'));
    await tester.enterText(find.byType(TextField).last, '{bad json');
    await _tapText(tester, '导入');
    await _pumpUntilFound(tester, find.textContaining('导入失败:'));
    await _tapText(tester, '取消');
    await tester.pumpAndSettle();
    await _tapText(tester, '导入数据');
    await _pumpUntilFound(tester, find.text('导入数据'));
    await tester.enterText(
      find.byType(TextField).last,
      '{"categories":[],"lifeItems":[],"billRecords":[]}',
    );
    await _tapText(tester, '导入');
    await _pumpUntilFound(tester, find.text('数据导入成功'));
    await _tapText(tester, '导出数据');
    await _pumpUntilFound(tester, find.textContaining('数据已导出至:'));
  });
}

Future<void> _createPlainItem(WidgetTester tester, String title) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await tester.enterText(find.byType(TextFormField).first, title);
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(title));
}

Future<void> _createTemplateItem(WidgetTester tester, String template) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await _tapText(tester, '模板');
  await _pumpUntilFound(tester, find.text('快捷模板'));
  await _tapText(tester, template);
  await _pumpUntilFound(tester, find.text('新建事项'));
  if (template == '工资收入') {
    expect(find.text('收入'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '100.00');
  }
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(template));
}

Future<void> _coverAllTemplates(WidgetTester tester, int unique) async {
  const templates = [
    ('交水电费', '账单事项', '每月', '支出'),
    ('房租', '账单事项', '每月', '支出'),
    ('宽带续费', '账单事项', '每月', '支出'),
    ('会员订阅', '订阅/会员', '每月', '支出'),
    ('保险续费', '账单事项', '每年', '支出'),
    ('药品过期', '到期提醒', null, null),
    ('食品过期', '到期提醒', null, null),
    ('滤芯更换', '耗材更换', '每 180 天', '支出'),
    ('普通待办', '普通待办', null, null),
  ];

  var index = 0;
  for (final template in templates) {
    final title = '模板${template.$1} $unique $index';
    await _createTemplateItemWithTitle(
      tester,
      template: template.$1,
      title: title,
      amount: template.$4 == null ? null : '1.${index + 10}',
    );
    await _openItemDetail(tester, title);
    expect(find.text(template.$2), findsOneWidget);
    if (template.$3 != null) {
      expect(find.text(template.$3!), findsOneWidget);
    }
    if (template.$4 != null) {
      expect(find.text(template.$4!), findsOneWidget);
    }
    await _tapBack(tester);
    await _pumpUntilFound(tester, find.text('生活事项'));
    index += 1;
  }
}

Future<void> _createTemplateItemWithTitle(
  WidgetTester tester, {
  required String template,
  required String title,
  String? amount,
}) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await _tapText(tester, '模板');
  await _pumpUntilFound(tester, find.text('快捷模板'));
  await _tapText(tester, template);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await tester.enterText(find.byType(TextFormField).first, title);
  if (amount != null) {
    await tester.enterText(find.byType(TextFormField).at(1), amount);
  }
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(title));
}

Future<void> _createRecurringItem(WidgetTester tester, String title) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await tester.enterText(find.byType(TextFormField).first, title);
  await _tapText(tester, '重复');
  await _pumpUntilFound(tester, find.text('重复频率'));
  await _selectDropdownOption(tester, currentValue: '每天', newValue: '每周');
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(title));
}

Future<void> _createCustomRecurringItem(
  WidgetTester tester,
  String title,
) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await tester.enterText(find.byType(TextFormField).first, title);
  await _tapText(tester, '重复');
  await _pumpUntilFound(tester, find.text('重复频率'));
  await _selectDropdownOption(tester, currentValue: '每天', newValue: '自定义');
  await tester.enterText(find.byType(TextFormField).at(1), '45');
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(title));
}

Future<void> _createCategoryAndDateItem(
  WidgetTester tester,
  String title,
) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await tester.enterText(find.byType(TextFormField).first, title);
  await _selectDropdownOption(tester, currentValue: '分类', newValue: '普通待办');
  await tester.tap(find.byKey(const ValueKey('life-item-date-field')));
  await tester.pumpAndSettle();
  await _confirmDatePicker(tester);
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(title));
}

Future<void> _createBillableItemAndRecordBill(
  WidgetTester tester,
  String title,
) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await tester.enterText(find.byType(TextFormField).first, title);
  await _selectDropdownOption(tester, currentValue: '无金额', newValue: '支出');
  await tester.enterText(find.byType(TextFormField).at(1), '23.45');
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(title));

  await _openItemDetail(tester, title);
  await _tapText(tester, '完成');
  await _pumpUntilFound(tester, find.text('完成并记账'));
  await _tapText(tester, '完成并记账');
  await _pumpUntilFound(tester, find.text('记账详情'));
  await _tapText(tester, '确认');
  await _pumpUntilFound(tester, find.text('生活事项'));
}

Future<void> _createBillableItemAndRecordBillFromList(
  WidgetTester tester,
  String title,
) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建事项'));
  await tester.enterText(find.byType(TextFormField).first, title);
  await _selectDropdownOption(tester, currentValue: '无金额', newValue: '支出');
  await tester.enterText(find.byType(TextFormField).at(1), '34.56');
  await _tapText(tester, '创建事项');
  await _pumpUntilFound(tester, find.text(title));

  await _tapCardActionForTitle(tester, title, '完成');
  await _pumpUntilFound(tester, find.text('完成并记账'));
  await _tapText(tester, '完成并记账');
  await _pumpUntilFound(tester, find.text('记账详情'));
  await _tapText(tester, '确认');
  await _pumpUntilFound(tester, find.text('生活事项'));
  expect(find.text(title), findsWidgets);
}

Future<void> _createRecurringBillItemAndGenerateNext(
  WidgetTester tester,
  String title,
) async {
  await _createTemplateItemWithTitle(
    tester,
    template: '交水电费',
    title: title,
    amount: '45.67',
  );
  await _tapCardActionForTitle(tester, title, '完成');
  await _pumpUntilFound(tester, find.text('完成并生成下一轮'));
  await _tapText(tester, '完成并生成下一轮');
  await _pumpUntilFound(tester, find.text('记账详情'));
  await _tapText(tester, '确认');
  await _pumpUntilFound(tester, find.text('生活事项'));
}

Future<void> _createBill(
  WidgetTester tester, {
  required String title,
  required String amount,
  String amountType = '支出',
  String? category,
  bool pickDate = false,
}) async {
  await _tapIcon(tester, Icons.add);
  await _pumpUntilFound(tester, find.text('新建账单'));
  await tester.enterText(find.byType(TextFormField).at(0), title);
  if (amountType == '收入') {
    await _selectDropdownOption(tester, currentValue: '支出', newValue: '收入');
  }
  await tester.enterText(find.byType(TextFormField).at(1), amount);
  if (category != null) {
    await _selectDropdownOption(tester, currentValue: '分类', newValue: category);
  }
  if (pickDate) {
    await tester.tap(find.byKey(const ValueKey('bill-date-field')));
    await tester.pumpAndSettle();
    await _confirmDatePicker(tester);
  }
  await _tapText(tester, '创建账单');
  await _pumpUntilFound(tester, find.text(title));
}

Future<void> _tapCardActionForTitle(
  WidgetTester tester,
  String title,
  String action,
) async {
  final card = find
      .ancestor(of: find.text(title), matching: find.byType(Card))
      .first;
  final actionFinder = find.descendant(of: card, matching: find.text(action));
  await tester.ensureVisible(actionFinder);
  await tester.pumpAndSettle();
  await tester.tap(actionFinder);
  await tester.pumpAndSettle();
}

Future<void> _confirmDatePicker(WidgetTester tester) async {
  await _pumpUntilFound(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is Text && (widget.data == '确定' || widget.data == 'OK'),
    ),
  );
  final okFinder = find
      .byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data == '确定' || widget.data == 'OK'),
      )
      .last;
  await tester.tap(okFinder);
  await tester.pumpAndSettle();
}

Future<void> _openItemDetail(WidgetTester tester, String title) async {
  await _tapText(tester, title);
  await _pumpUntilFound(tester, find.text('事项详情'));
}

Future<void> _selectDropdownOption(
  WidgetTester tester, {
  required String currentValue,
  required String newValue,
}) async {
  final currentFinder = find.text(currentValue).last;
  await tester.ensureVisible(currentFinder);
  await tester.tap(currentFinder, warnIfMissed: false);
  await tester.pumpAndSettle();
  final optionFinder = find.text(newValue).last;
  await tester.tap(optionFinder);
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await _tapText(tester, label);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final allMatches = find.text(text);
  if (allMatches.evaluate().isEmpty) {
    await _scrollUntilVisible(tester, allMatches);
  }
  final finder = allMatches.last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  final finder = find.byIcon(icon).last;
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back').last);
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  await tester.scrollUntilVisible(
    finder,
    500,
    scrollable: scrollables.last,
    maxScrolls: 20,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  try {
    await _scrollUntilVisible(tester, finder);
    if (finder.evaluate().isNotEmpty) return;
  } catch (_) {
    // Some routes do not have a scrollable, or the target is genuinely absent.
  }
  expect(finder, findsWidgets);
}

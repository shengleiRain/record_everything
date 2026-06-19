import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/utils/money_formatter.dart';
import '../providers/home_providers.dart';

/// Widget 数据同步服务。spec §4.2。
/// 把今日待办 + 月度收支写入 SharedPreferences，供 Android Widget 读取。
class WidgetSyncService {
  /// 同步数据到 Widget。调用时机：App 进入后台 / 数据变更。
  static Future<void> sync({
    required String dateLabel,
    required int todayCount,
    required int overdueCount,
    required List<WidgetItemData> items,
    required String monthlyIncome,
    required String monthlyExpense,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>('widget_date', dateLabel),
      HomeWidget.saveWidgetData<int>('widget_today_count', todayCount),
      HomeWidget.saveWidgetData<int>('widget_overdue_count', overdueCount),
      HomeWidget.saveWidgetData<String>(
        'widget_items',
        formatWidgetItems(items),
      ),
      HomeWidget.saveWidgetData<String>(
        'widget_monthly_income',
        monthlyIncome,
      ),
      HomeWidget.saveWidgetData<String>(
        'widget_monthly_expense',
        monthlyExpense,
      ),
    ]);
    await HomeWidget.updateWidget(
      qualifiedAndroidName:
          'com.lifeitems.record_everything.HomeWidgetProvider',
    );
  }

  /// 从 Riverpod providers 读取数据并同步到 Widget。
  static Future<void> syncFromProviders(ProviderContainer container) async {
    try {
      final now = DateTime.now();
      const weekday = [
        '周一',
        '周二',
        '周三',
        '周四',
        '周五',
        '周六',
        '周日',
      ];
      final dateLabel = '${now.month}月${now.day}日 ${weekday[now.weekday - 1]}';

      final agenda = await container.read(homeSelectedDayAgendaProvider.future);
      final todayItems = agenda
          .where((a) => !a.isCompleted)
          .map(
            (a) => WidgetItemData(title: a.title, isOverdue: a.isOverdue),
          )
          .toList();
      final overdueCount = todayItems.where((i) => i.isOverdue).length;

      final income = await container.read(homeMonthlyIncomeProvider.future);
      final expense = await container.read(homeMonthlyExpenseProvider.future);

      await sync(
        dateLabel: dateLabel,
        todayCount: todayItems.length,
        overdueCount: overdueCount,
        items: todayItems,
        monthlyIncome: MoneyFormatter.format(income),
        monthlyExpense: MoneyFormatter.format(expense),
      );
    } catch (_) {
      // 静默失败，不阻断 App。
    }
  }

  /// 将待办列表格式化为 JSON 字符串（最多 3 条）。
  static String formatWidgetItems(List<WidgetItemData> items) {
    final list = items
        .take(3)
        .map(
          (e) => {
            'title': e.title,
            'isOverdue': e.isOverdue,
          },
        )
        .toList();
    return jsonEncode(list);
  }
}

/// 单条待办数据（用于 Widget 显示）。
@immutable
class WidgetItemData {
  const WidgetItemData({required this.title, required this.isOverdue});
  final String title;
  final bool isOverdue;
}

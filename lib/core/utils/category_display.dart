import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';

/// 分类名显示翻译。spec §5.2。
///
/// 优先级：
/// 1. 用户自建分类（builtinKey == null）：原样返回 name。
/// 2. 内置分类被用户改名（name != originalName）：返回用户改的 name。
/// 3. 内置分类未改名：按 builtinKey 翻译，缺失兜底 name。
String categoryDisplayName(BuildContext context, Category c) {
  return categoryDisplayNameFor(
    context: context,
    name: c.name,
    builtinKey: c.builtinKey,
    originalName: c.originalName,
  );
}

/// 与 [categoryDisplayName] 相同逻辑，但接受裸参数（便于测试，避免 drift 依赖）。
String categoryDisplayNameFor({
  required BuildContext context,
  required String name,
  required String? builtinKey,
  required String? originalName,
}) {
  // 1. 用户自建分类。
  if (builtinKey == null) return name;
  // 2. 内置分类被用户改名：保留用户输入，不随语言覆盖。
  if (originalName != null && name != originalName) return name;
  // 3. 内置分类未改名：走翻译，缺失兜底 name。
  final l = AppLocalizations.of(context);
  return _lookupCategory(l, builtinKey) ?? name;
}

/// 分类 builtin_key → 翻译。与 gen-l10n 生成的 getter 一一对应。
String? _lookupCategory(AppLocalizations l, String key) {
  switch (key) {
    case 'cat_salary':
      return l.cat_salary;
    case 'cat_bonus':
      return l.cat_bonus;
    case 'cat_parttime':
      return l.cat_parttime;
    case 'cat_reimbursement':
      return l.cat_reimbursement;
    case 'cat_investment':
      return l.cat_investment;
    case 'cat_refund':
      return l.cat_refund;
    case 'cat_income_other':
      return l.cat_income_other;
    case 'cat_food':
      return l.cat_food;
    case 'cat_shopping':
      return l.cat_shopping;
    case 'cat_transport':
      return l.cat_transport;
    case 'cat_housing':
      return l.cat_housing;
    case 'cat_utilities':
      return l.cat_utilities;
    case 'cat_telecom':
      return l.cat_telecom;
    case 'cat_medical':
      return l.cat_medical;
    case 'cat_subscription':
      return l.cat_subscription;
    case 'cat_household':
      return l.cat_household;
    case 'cat_education':
      return l.cat_education;
    case 'cat_entertainment':
      return l.cat_entertainment;
    case 'cat_gift':
      return l.cat_gift;
    case 'cat_travel':
      return l.cat_travel;
    case 'cat_insurance':
      return l.cat_insurance;
    case 'cat_tax_fees':
      return l.cat_tax_fees;
    case 'cat_expense_other':
      return l.cat_expense_other;
    case 'cat_todo':
      return l.cat_todo;
    case 'cat_document':
      return l.cat_document;
    case 'cat_bill_reminder':
      return l.cat_bill_reminder;
    case 'cat_renewal':
      return l.cat_renewal;
    case 'cat_warranty':
      return l.cat_warranty;
    case 'cat_health':
      return l.cat_health;
    case 'cat_grocery_stock':
      return l.cat_grocery_stock;
    case 'cat_household_item':
      return l.cat_household_item;
    case 'cat_device':
      return l.cat_device;
    case 'cat_item_other':
      return l.cat_item_other;
    case 'cat_personal_project':
      return l.cat_personal_project;
    case 'cat_client_project':
      return l.cat_client_project;
    case 'cat_family_project':
      return l.cat_family_project;
    case 'cat_event':
      return l.cat_event;
    case 'cat_trip':
      return l.cat_trip;
    case 'cat_learning':
      return l.cat_learning;
    case 'cat_photo_order':
      return l.cat_photo_order;
    case 'cat_photo_follow':
      return l.cat_photo_follow;
    case 'cat_project_other':
      return l.cat_project_other;
    default:
      return null;
  }
}

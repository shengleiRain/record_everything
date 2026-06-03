import 'package:flutter/material.dart';

class TemplateData {
  final String title;
  final String itemType;
  final String amountType;
  final String? repeatRule;
  final String? categoryName;

  const TemplateData({
    required this.title,
    required this.itemType,
    required this.amountType,
    this.repeatRule,
    this.categoryName,
  });
}

const templates = [
  TemplateData(title: '交水电费', itemType: 'bill', amountType: 'expense', repeatRule: 'monthly', categoryName: '水电燃气'),
  TemplateData(title: '房租', itemType: 'bill', amountType: 'expense', repeatRule: 'monthly', categoryName: '住房'),
  TemplateData(title: '宽带续费', itemType: 'bill', amountType: 'expense', repeatRule: 'monthly', categoryName: '通信网络'),
  TemplateData(title: '会员订阅', itemType: 'subscription', amountType: 'expense', repeatRule: 'monthly', categoryName: '订阅会员'),
  TemplateData(title: '保险续费', itemType: 'bill', amountType: 'expense', repeatRule: 'yearly', categoryName: '保险'),
  TemplateData(title: '证件到期', itemType: 'expiration', amountType: 'none', categoryName: '证件'),
  TemplateData(title: '药品过期', itemType: 'expiration', amountType: 'none', categoryName: '药品'),
  TemplateData(title: '食品过期', itemType: 'expiration', amountType: 'none', categoryName: '食品'),
  TemplateData(title: '滤芯更换', itemType: 'consumable', amountType: 'expense', repeatRule: 'every:180:days', categoryName: '家庭耗材'),
  TemplateData(title: '工资收入', itemType: 'bill', amountType: 'income', repeatRule: 'monthly', categoryName: '工资'),
  TemplateData(title: '普通待办', itemType: 'todo', amountType: 'none', categoryName: '普通待办'),
];

void showQuickTemplateSheet(BuildContext context, void Function(TemplateData) onSelect) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('快捷模板', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: templates.map((t) => ActionChip(
              label: Text(t.title),
              onPressed: () {
                onSelect(t);
                Navigator.pop(context);
              },
            )).toList(),
          ),
        ],
      ),
    ),
  );
}

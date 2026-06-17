import 'package:flutter/material.dart';

class TemplateData {
  final String title;
  final String amountType;
  final String? repeatRule;
  final String? categoryName;

  const TemplateData({
    required this.title,
    required this.amountType,
    this.repeatRule,
    this.categoryName,
  });
}

const templates = [
  TemplateData(
    title: '交水电费',
    amountType: 'expense',
    repeatRule: 'monthly',
    categoryName: '水电燃气',
  ),
  TemplateData(
    title: '房租',
    amountType: 'expense',
    repeatRule: 'monthly',
    categoryName: '住房',
  ),
  TemplateData(
    title: '宽带续费',
    amountType: 'expense',
    repeatRule: 'monthly',
    categoryName: '通信网络',
  ),
  TemplateData(
    title: '会员订阅',
    amountType: 'expense',
    repeatRule: 'monthly',
    categoryName: '订阅续费',
  ),
  TemplateData(
    title: '保险续费',
    amountType: 'expense',
    repeatRule: 'yearly',
    categoryName: '账单提醒',
  ),
  TemplateData(title: '证件到期', amountType: 'none', categoryName: '证件'),
  TemplateData(title: '药品过期', amountType: 'none', categoryName: '药品健康'),
  TemplateData(title: '食品过期', amountType: 'none', categoryName: '食品库存'),
  TemplateData(
    title: '滤芯更换',
    amountType: 'expense',
    repeatRule: 'every:180:days',
    categoryName: '家庭耗材',
  ),
  TemplateData(title: '工资收入', amountType: 'income', repeatRule: 'monthly'),
  TemplateData(title: '待办', amountType: 'none', categoryName: '待办'),
];

void showQuickTemplateSheet(
  BuildContext context,
  void Function(TemplateData) onSelect,
) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷模板', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: templates
                  .map(
                    (t) => ActionChip(
                      label: Text(t.title),
                      onPressed: () {
                        onSelect(t);
                        Navigator.pop(context);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

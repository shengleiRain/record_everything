import 'package:flutter/material.dart';

class CategoryIconOption {
  const CategoryIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const List<CategoryIconOption> categoryIconOptions = [
  CategoryIconOption(
    key: 'category',
    label: '分类',
    icon: Icons.category_outlined,
  ),
  CategoryIconOption(key: 'restaurant', label: '餐饮', icon: Icons.restaurant),
  CategoryIconOption(
    key: 'local_cafe',
    label: '咖啡',
    icon: Icons.local_cafe_outlined,
  ),
  CategoryIconOption(
    key: 'shopping_bag',
    label: '购物',
    icon: Icons.shopping_bag_outlined,
  ),
  CategoryIconOption(
    key: 'directions_car',
    label: '交通',
    icon: Icons.directions_car_outlined,
  ),
  CategoryIconOption(key: 'home', label: '家庭', icon: Icons.home_outlined),
  CategoryIconOption(key: 'bolt', label: '水电', icon: Icons.bolt_outlined),
  CategoryIconOption(key: 'wifi', label: '网络', icon: Icons.wifi),
  CategoryIconOption(
    key: 'medical_services',
    label: '医疗',
    icon: Icons.medical_services_outlined,
  ),
  CategoryIconOption(
    key: 'subscriptions',
    label: '订阅',
    icon: Icons.subscriptions_outlined,
  ),
  CategoryIconOption(
    key: 'cleaning_services',
    label: '耗材',
    icon: Icons.cleaning_services_outlined,
  ),
  CategoryIconOption(key: 'school', label: '学习', icon: Icons.school_outlined),
  CategoryIconOption(
    key: 'sports_esports',
    label: '娱乐',
    icon: Icons.sports_esports_outlined,
  ),
  CategoryIconOption(
    key: 'security',
    label: '保险',
    icon: Icons.security_outlined,
  ),
  CategoryIconOption(key: 'redeem', label: '礼物', icon: Icons.redeem_outlined),
  CategoryIconOption(key: 'flight', label: '旅行', icon: Icons.flight_outlined),
  CategoryIconOption(
    key: 'request_quote',
    label: '税费',
    icon: Icons.request_quote_outlined,
  ),
  CategoryIconOption(key: 'work', label: '工作', icon: Icons.work_outline),
  CategoryIconOption(
    key: 'emoji_events',
    label: '奖金',
    icon: Icons.emoji_events_outlined,
  ),
  CategoryIconOption(key: 'schedule', label: '时间', icon: Icons.schedule),
  CategoryIconOption(key: 'receipt', label: '票据', icon: Icons.receipt_outlined),
  CategoryIconOption(key: 'trending_up', label: '收益', icon: Icons.trending_up),
  CategoryIconOption(key: 'undo', label: '退款', icon: Icons.undo),
  CategoryIconOption(key: 'badge', label: '证件', icon: Icons.badge_outlined),
  CategoryIconOption(
    key: 'receipt_long',
    label: '账单',
    icon: Icons.receipt_long_outlined,
  ),
  CategoryIconOption(
    key: 'card_membership',
    label: '会员',
    icon: Icons.card_membership_outlined,
  ),
  CategoryIconOption(key: 'build', label: '维修', icon: Icons.build_outlined),
  CategoryIconOption(
    key: 'medication',
    label: '药品',
    icon: Icons.medication_outlined,
  ),
  CategoryIconOption(key: 'kitchen', label: '库存', icon: Icons.kitchen_outlined),
  CategoryIconOption(
    key: 'devices_other',
    label: '设备',
    icon: Icons.devices_other_outlined,
  ),
  CategoryIconOption(
    key: 'check_circle',
    label: '待办',
    icon: Icons.check_circle_outline,
  ),
  CategoryIconOption(key: 'person', label: '个人', icon: Icons.person_outline),
  CategoryIconOption(
    key: 'business_center',
    label: '客户',
    icon: Icons.business_center_outlined,
  ),
  CategoryIconOption(key: 'event', label: '活动', icon: Icons.event_outlined),
  CategoryIconOption(
    key: 'camera_alt',
    label: '摄影',
    icon: Icons.camera_alt_outlined,
  ),
  CategoryIconOption(key: 'folder', label: '项目', icon: Icons.folder_outlined),
  CategoryIconOption(key: 'more_horiz', label: '其他', icon: Icons.more_horiz),
];

IconData categoryIconData(String? key) {
  return categoryIconOption(key).icon;
}

CategoryIconOption categoryIconOption(String? key) {
  return categoryIconOptions.firstWhere(
    (option) => option.key == key,
    orElse: () => categoryIconOptions.first,
  );
}

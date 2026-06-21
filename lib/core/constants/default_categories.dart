/// 内置默认分类。spec §5.2。
///
/// 每条含三个字段：
/// - `name`：中文名称（作为兜底显示与数据库存储值）。
/// - `icon`：Material icon 名称。
/// - `key`：稳定的 i18n key（如 `cat_food`），用于显示层翻译。
///   用户自建分类无 key（builtinKey = null），原样显示 name。
class DefaultCategories {
  static const income = [
    {'name': '工资', 'icon': 'work', 'key': 'cat_salary'},
    {'name': '奖金', 'icon': 'emoji_events', 'key': 'cat_bonus'},
    {'name': '兼职', 'icon': 'schedule', 'key': 'cat_parttime'},
    {'name': '报销', 'icon': 'receipt', 'key': 'cat_reimbursement'},
    {'name': '投资收益', 'icon': 'trending_up', 'key': 'cat_investment'},
    {'name': '退款返现', 'icon': 'undo', 'key': 'cat_refund'},
    {'name': '其他收入', 'icon': 'more_horiz', 'key': 'cat_income_other'},
  ];

  static const expense = [
    {'name': '餐饮', 'icon': 'restaurant', 'key': 'cat_food'},
    {'name': '购物', 'icon': 'shopping_bag', 'key': 'cat_shopping'},
    {'name': '交通', 'icon': 'directions_car', 'key': 'cat_transport'},
    {'name': '住房', 'icon': 'home', 'key': 'cat_housing'},
    {'name': '水电燃气', 'icon': 'bolt', 'key': 'cat_utilities'},
    {'name': '通信网络', 'icon': 'wifi', 'key': 'cat_telecom'},
    {'name': '医疗药品', 'icon': 'medical_services', 'key': 'cat_medical'},
    {'name': '会员订阅', 'icon': 'subscriptions', 'key': 'cat_subscription'},
    {'name': '家庭耗材', 'icon': 'cleaning_services', 'key': 'cat_household'},
    {'name': '教育', 'icon': 'school', 'key': 'cat_education'},
    {'name': '娱乐', 'icon': 'sports_esports', 'key': 'cat_entertainment'},
    {'name': '人情礼物', 'icon': 'redeem', 'key': 'cat_gift'},
    {'name': '旅行差旅', 'icon': 'flight', 'key': 'cat_travel'},
    {'name': '保险', 'icon': 'security', 'key': 'cat_insurance'},
    {'name': '税费手续费', 'icon': 'request_quote', 'key': 'cat_tax_fees'},
    {'name': '其他支出', 'icon': 'more_horiz', 'key': 'cat_expense_other'},
  ];

  static const item = [
    {'name': '待办', 'icon': 'check_circle', 'key': 'cat_todo'},
    {'name': '证件', 'icon': 'badge', 'key': 'cat_document'},
    {'name': '账单提醒', 'icon': 'receipt_long', 'key': 'cat_bill_reminder'},
    {'name': '订阅续费', 'icon': 'card_membership', 'key': 'cat_renewal'},
    {'name': '保修售后', 'icon': 'build', 'key': 'cat_warranty'},
    {'name': '药品健康', 'icon': 'medication', 'key': 'cat_health'},
    {'name': '食品库存', 'icon': 'kitchen', 'key': 'cat_grocery_stock'},
    {'name': '家庭耗材', 'icon': 'cleaning_services', 'key': 'cat_household_item'},
    {'name': '车辆设备', 'icon': 'devices_other', 'key': 'cat_device'},
    {'name': '其他事项', 'icon': 'more_horiz', 'key': 'cat_item_other'},
  ];

  static const project = [
    {'name': '个人项目', 'icon': 'person', 'key': 'cat_personal_project'},
    {'name': '客户项目', 'icon': 'business_center', 'key': 'cat_client_project'},
    {'name': '家庭事务', 'icon': 'home', 'key': 'cat_family_project'},
    {'name': '活动安排', 'icon': 'event', 'key': 'cat_event'},
    {'name': '旅行计划', 'icon': 'flight', 'key': 'cat_trip'},
    {'name': '学习成长', 'icon': 'school', 'key': 'cat_learning'},
    {'name': '摄影接单', 'icon': 'camera_alt', 'key': 'cat_photo_order'},
    {'name': '跟拍', 'icon': 'photo_camera', 'key': 'cat_photo_follow'},
    {'name': '其他项目', 'icon': 'folder', 'key': 'cat_project_other'},
  ];
}

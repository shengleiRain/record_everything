enum ItemType {
  todo('todo', '普通待办'),
  expiration('expiration', '到期提醒'),
  bill('bill', '账单事项'),
  recurring('recurring', '周期事项'),
  subscription('subscription', '订阅/会员'),
  consumable('consumable', '耗材更换'),
  paymentDue('payment_due', '待收款'),
  milestone('milestone', '里程碑'),
  delivery('delivery', '交付节点');

  const ItemType(this.value, this.label);
  final String value;
  final String label;

  static ItemType fromString(String v) => ItemType.values.firstWhere(
    (e) => e.value == v,
    orElse: () => ItemType.todo,
  );
}

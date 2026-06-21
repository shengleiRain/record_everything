/// 智能录入解析用的词表与中文数字转换。详见 spec §5.2。
library;

// ===== 中文数字转阿拉伯 =====

const _digit = {
  '零': 0,
  '一': 1,
  '二': 2,
  '两': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
};

/// 纯阿拉伯数字串快速通道。
final _plainDigits = RegExp(r'^[0-9]+$');

/// 将连读中文数字（金额高频场景）转阿拉伯整数。
/// 无法解析返回 null。仅覆盖十万以内常用写法，复杂长串交给云端。
int? chineseNumberToArabic(String s) {
  if (s.isEmpty) return null;
  if (_plainDigits.hasMatch(s)) return int.tryParse(s);

  int total = 0;
  int section = 0;
  int? current;
  bool sawWan = false; // 万之后的裸数字按"千"读（"两万三"=23000）

  bool handleChar(String ch) {
    if (ch == '十') {
      current = (current ?? 0) == 0 ? 1 : current;
      section += current! * 10;
      current = null;
      return true;
    }
    if (ch == '百') {
      if (current == null) return false;
      section += current! * 100;
      current = null;
      return true;
    }
    if (ch == '千') {
      if (current == null) return false;
      section += current! * 1000;
      current = null;
      return true;
    }
    if (ch == '万') {
      section += current ?? 0;
      current = null;
      total += section * 10000;
      section = 0;
      sawWan = true;
      return true;
    }
    final d = _digit[ch];
    if (d == null) return false;
    if (current != null) {
      // 连续数字（如"二五"），按多位拼接
      current = current! * 10 + d;
    } else {
      current = d;
    }
    return true;
  }

  for (final ch in s.runes.map(String.fromCharCode)) {
    if (!handleChar(ch)) return null;
  }
  // 万之后出现的裸数字（无千/百/十单位），口语读作"几千"。
  // 例：两万三 → 2万 + 3千 = 23000。
  if (sawWan && current != null && section == 0 && current! < 10) {
    return total + current! * 1000;
  }
  return total + section + (current ?? 0);
}

// ===== 动词词表（事项/账单判定） =====

/// 出现则强倾向账单。
const expenseVerbs = <String>[
  '花了',
  '买了',
  '消费',
  '支出',
  '付款',
  '付了',
  '充值',
];

/// 出现则强倾向收入账单。
const incomeVerbs = <String>[
  '工资',
  '收入',
  '收到',
  '退款',
  '报销',
  '奖金',
  '到账',
];

/// 出现则倾向事项。
const taskVerbs = <String>[
  '开会',
  '提醒',
  '记得',
  '别忘了',
  '办',
  '办理',
  '交',
  '预约',
  '带',
];

// ===== 金额/单位 =====

/// 金额正则：匹配带或不带货币符号的数字（含小数）。捕获组 1 为纯数字串。
/// 否定先行：数字后紧跟"点/时/号"的是时间/日期（"3点"、"15号"），不算金额。
final amountPattern = RegExp(
  r'(?:[￥¥]|RMB|人民币)?\s*(\d+(?:\.\d+)?)(?![点时号])',
);

/// 货币符号集合，用于判定是否有金额上下文。
const currencyMarkers = [
  '￥',
  '¥',
  'RMB',
  '人民币',
  '元',
  '块',
  '毛',
  '角',
];

// ===== 分类关键词（用于 categoryGuess 文本抽取，匹配分类 id 交给 CategoryMatcher） =====

/// 关键词 → categoryGuess 文本（供 CategoryMatcher 用本地分类表二次匹配 id）。
const categoryKeywords = <String, String>{
  '早餐': '餐饮',
  '午餐': '餐饮',
  '晚餐': '餐饮',
  '外卖': '餐饮',
  '吃饭': '餐饮',
  '咖啡': '餐饮',
  '奶茶': '餐饮',
  '打车': '交通',
  '地铁': '交通',
  '公交': '交通',
  '加油': '交通',
  '停车': '交通',
  '工资': '工资',
  '奖金': '工资',
  '报销': '工资',
  '话费': '通讯',
  '网费': '通讯',
  '流量': '通讯',
  '房租': '住房',
  '水电': '住房',
  '物业': '住房',
  '电影': '娱乐',
  '游戏': '娱乐',
  '会员': '娱乐',
  '续费': '订阅',
  '订阅': '订阅',
};

// ===== English category keywords =====

/// 英文关键词 → categoryGuess 文本。spec §5.3。
const categoryKeywordsEn = <String, String>{
  'breakfast': '餐饮',
  'lunch': '餐饮',
  'dinner': '餐饮',
  'coffee': '餐饮',
  'pizza': '餐饮',
  'takeout': '餐饮',
  'snack': '餐饮',
  'meal': '餐饮',
  'grocery': '餐饮',
  'uber': '交通',
  'taxi': '交通',
  'gas': '交通',
  'parking': '交通',
  'subway': '交通',
  'bus': '交通',
  'train': '交通',
  'flight': '交通',
  'rent': '住房',
  'electricity': '住房',
  'water': '住房',
  'phone': '通讯',
  'internet': '通讯',
  'salary': '工资',
  'bonus': '工资',
  'refund': '工资',
  'reimbursement': '工资',
  'movie': '娱乐',
  'game': '娱乐',
  'netflix': '娱乐',
  'spotify': '娱乐',
  'subscription': '订阅',
  'amazon': '购物',
  'shopping': '购物',
};

/// 按语言选择分类关键词表。
Map<String, String> categoryKeywordsFor(String languageCode) {
  return languageCode == 'en' ? categoryKeywordsEn : categoryKeywords;
}

# Smart Entry（智能录入）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 record_everything 引入一条"智能录入通道"：快速输入、识图记账、系统分享、语音输入四个入口共享一套本地优先 + 云端兜底（BYOK）的解析管道，经草稿确认页落库到现有的 LifeItem / BillRecord。

**Architecture:** 多入口、单管道。四个入口都把输入归一为纯文本喂给 `SmartEntryParser`；解析分两层——本地规则引擎先跑（覆盖 95% 高频输入），低置信段再走云端大模型（BYOK）兜底；产出内存中的 `EntryDraft`，经草稿确认页用户确认后复用现有 `lifeItemNotifierProvider` / `billRecordRepository` 落库。Android 优先实现，系统分享按平台抽象接口编写以预留 iOS。

**Tech Stack:** Flutter（现有），Riverpod（状态管理，现有），Drift（现有），go_router（现有），新增 `google_mlkit_text_recognition`、`image_picker`、`receive_sharing_intent`、`speech_to_text`、`flutter_secure_storage`、`http`。

**对应 Spec:** `docs/superpowers/specs/2026-06-19-smart-entry-design.md`

---

## 文件结构总览

新建文件（本计划创建）：

```
lib/
  features/smart_entry/
    models/draft_item.dart                 # DraftItem / EntryDraft / DraftKind / DraftSource（切片1）
    parser/
      smart_entry_parser.dart              # 管道编排入口（切片1骨架，切片7接入云端分支）
      preprocessor.dart                    # 文本预处理（切片1）
      splitter.dart                        # 分句（切片1）
      local_rule_engine.dart               # 本地规则引擎（切片1；切片4加 ocr 规则）
      cloud_parser.dart                    # CloudParser 抽象 + 各厂商实现（切片7）
    constants/smart_entry_keywords.dart    # 动词/单位/关键词词表（切片1）
    providers/smart_entry_providers.dart   # Riverpod providers（切片2起逐步补）
    services/
      category_matcher.dart                # category_guess 文本→分类ID 匹配（切片2）
      ocr_service.dart                     # ML Kit OCR 封装（切片4）
      share_receiver.dart                  # ShareReceiver 抽象 + AndroidShareReceiver（切片5）
      secure_key_store.dart                # BYOK Key 存取（切片7）
    pages/
      smart_entry_confirm_page.dart        # 草稿确认页（切片2）
      smart_entry_input_page.dart          # 快速输入页（切片3）
      ai_assistant_settings_page.dart      # BYOK 设置页（切片7）
    widgets/
      draft_item_card.dart                 # 草稿卡片（切片2）
      ocr_preview_panel.dart               # OCR 原文/图片预览（切片4）
      cloud_unavailable_banner.dart        # 云端降级提示条（切片7）

test/
  smart_entry/
    draft_item_test.dart                   # 切片1
    preprocessor_test.dart                 # 切片1
    splitter_test.dart                     # 切片1
    local_rule_engine_test.dart            # 切片1（重点）
    category_matcher_test.dart             # 切片2
    smart_entry_confirm_page_test.dart     # 切片2
    smart_entry_input_page_test.dart       # 切片3
    ocr_service_test.dart                  # 切片4（mock）
    share_receiver_test.dart               # 切片5
    cloud_parser_test.dart                 # 切片7（mock http）
```

修改文件（本计划修改）：
- `lib/features/home/widgets/quick_create_sheet.dart` —— 顶部加"智能输入"入口（切片3）
- `lib/core/router/app_router.dart` —— 新增 `/smart-entry/input`、`/smart-entry/confirm` 路由（切片2/3）
- `lib/features/settings/pages/settings_page.dart` —— 加"AI 助手"入口（切片7）
- `test/helpers/test_app.dart` —— 测试路由补 smart-entry 路由（切片2）
- `android/app/src/main/AndroidManifest.xml` —— 分享 intent-filter（切片5）
- `pubspec.yaml` —— 加依赖（各切片按需）

**复用的现有接入点（不改）**：
- `lifeItemRepoProvider` / `lifeItemNotifierProvider.create()` —— 事项落库（含提醒调度，见 `life_item_providers.dart:66`）
- `billRecordRepoProvider` / `BillRecordRepository.create()` —— 账单落库（见 `bill_record_repository.dart:17`，入参 `amount` 为整数分）
- `categoryDao.getByType(type)` / `categoryDao.getAll()` —— 分类匹配（见 `category_dao.dart:12`）
- `MoneyFormatter` —— 金额解析复用
- `pumpPageWithDatabase` / `TestAppHarness`（`test/helpers/test_app.dart`）—— 组件测试 harness

**重要数据约定**：金额一律用"整数分"存储（对齐 `BillRecordRepository.create(amount:)` 与 `LifeItemRepository.create(amount:)`）。`amountType` 字符串：事项 `none|income|expense`，账单 `income|expense`。

---

## Task 1: 数据模型 DraftItem / EntryDraft

**Files:**
- Create: `lib/features/smart_entry/models/draft_item.dart`
- Test: `test/smart_entry/draft_item_test.dart`

- [ ] **Step 1: 写失败测试**

`test/smart_entry/draft_item_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';

void main() {
  group('DraftItem', () {
    test('copyWith 更新单个字段保留其余', () {
      final item = DraftItem(
        kind: DraftKind.bill,
        title: '午餐',
        amountCents: 2500,
        amountType: DraftAmountType.expense,
        time: DateTime(2026, 6, 19, 12),
        source: DraftSource.nl,
        confidence: 0.9,
      );
      final updated = item.copyWith(title: '晚餐', amountCents: 5000);
      expect(updated.title, '晚餐');
      expect(updated.amountCents, 5000);
      expect(updated.kind, DraftKind.bill); // 其余字段保留
    });

    test('isLowConfidence 阈值 0.6', () {
      final low = DraftItem(
        kind: DraftKind.bill, title: 'x', amountCents: 0,
        amountType: DraftAmountType.expense, time: DateTime(2026, 6, 19),
        source: DraftSource.ocr, confidence: 0.55,
      );
      final high = low.copyWith(confidence: 0.8);
      expect(low.isLowConfidence, isTrue);
      expect(high.isLowConfidence, isFalse);
    });
  });

  group('EntryDraft', () {
    test('空态工厂', () {
      final empty = EntryDraft.empty(DraftSource.nl, rawInput: '?');
      expect(empty.items, isEmpty);
      expect(empty.rawInput, '?');
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/draft_item_test.dart`
Expected: FAIL — 文件/类型不存在（`Target of URI doesn't exist`）

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/models/draft_item.dart`:
```dart
/// 智能录入解析产出的草稿项。不可变值对象，确认前只存在内存里。
///
/// 设计与现有实体分离（不复用 LifeItem/BillRecord），保持
/// "未落库草稿"与"已落库实体"的清晰边界。详见 spec §4。
library;

import 'package:flutter/foundation.dart';

enum DraftKind { lifeItem, bill }

enum DraftSource { nl, ocr, share, voice }

/// 草稿里的金额类型。账单无 none；事项可为 none（无金额的待办）。
enum DraftAmountType { none, income, expense }

extension DraftAmountTypeX on DraftAmountType {
  String get value => name;
  static DraftAmountType fromString(String v) =>
      DraftAmountType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => DraftAmountType.none,
      );
}

@immutable
class DraftItem {
  final DraftKind kind;
  final String title;
  final int? amountCents;
  final DraftAmountType amountType;
  final DateTime time; // 事项=dueTime，账单=billTime
  final DateTime? remindTime; // 仅事项
  final String? repeatRule; // 仅事项，复用现有 RepeatRule 字符串格式
  final int? categoryId; // 已匹配到本地分类 id；为空时用 categoryGuess
  final String? categoryGuess; // 文本（如"餐饮"），供确认页下拉选择
  final double confidence; // 0.0~1.0
  final List<String> parseNotes;
  final DraftSource source;

  const DraftItem({
    required this.kind,
    required this.title,
    required this.amountCents,
    required this.amountType,
    required this.time,
    this.remindTime,
    this.repeatRule,
    this.categoryId,
    this.categoryGuess,
    required this.confidence,
    this.parseNotes = const [],
    required this.source,
  });

  static const double _lowConfidenceThreshold = 0.6;

  bool get isLowConfidence => confidence < _lowConfidenceThreshold;

  DraftItem copyWith({
    DraftKind? kind,
    String? title,
    Object? amountCents = _sentinel,
    DraftAmountType? amountType,
    DateTime? time,
    Object? remindTime = _sentinel,
    Object? repeatRule = _sentinel,
    Object? categoryId = _sentinel,
    Object? categoryGuess = _sentinel,
    double? confidence,
    List<String>? parseNotes,
    DraftSource? source,
  }) {
    return DraftItem(
      kind: kind ?? this.kind,
      title: title ?? this.title,
      amountCents: amountCents == _sentinel
          ? this.amountCents
          : amountCents as int?,
      amountType: amountType ?? this.amountType,
      time: time ?? this.time,
      remindTime: remindTime == _sentinel
          ? this.remindTime
          : remindTime as DateTime?,
      repeatRule: repeatRule == _sentinel
          ? this.repeatRule
          : repeatRule as String?,
      categoryId: categoryId == _sentinel
          ? this.categoryId
          : categoryId as int?,
      categoryGuess: categoryGuess == _sentinel
          ? this.categoryGuess
          : categoryGuess as String?,
      confidence: confidence ?? this.confidence,
      parseNotes: parseNotes ?? this.parseNotes,
      source: source ?? this.source,
    );
  }

  static const Object _sentinel = Object();
}

@immutable
class EntryDraft {
  final List<DraftItem> items;
  final DraftSource source;
  final String rawInput;
  final String? ocrFullText; // 仅 OCR 来源保留

  const EntryDraft({
    required this.items,
    required this.source,
    required this.rawInput,
    this.ocrFullText,
  });

  factory EntryDraft.empty(DraftSource source, {required String rawInput}) {
    return EntryDraft(
      items: const [],
      source: source,
      rawInput: rawInput,
    );
  }

  bool get isEmpty => items.isEmpty;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/draft_item_test.dart`
Expected: PASS（2 组 3 用例全过）

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/models/draft_item.dart test/smart_entry/draft_item_test.dart
git commit -m "feat(smart-entry): add DraftItem/EntryDraft data model"
```

---

## Task 2: 文本预处理 Preprocessor

**Files:**
- Create: `lib/features/smart_entry/parser/preprocessor.dart`
- Test: `test/smart_entry/preprocessor_test.dart`

- [ ] **Step 1: 写失败测试**

`test/smart_entry/preprocessor_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/parser/preprocessor.dart';

void main() {
  const p = Preprocessor();

  test('全角转半角', () {
    expect(p.normalize('花了２５元，。'), '花了25元,.');
  });

  test('中文数字转阿拉伯（基础）', () {
    expect(p.normalize('花了二十五'), '花了25');
    expect(p.normalize('一百二十'), '120');
    expect(p.normalize('两万三'), '23000');
  });

  test('单位词 1k/1w 等转数字', () {
    expect(p.normalize('花了1k'), '花了1000');
    expect(p.normalize('花了2w'), '花了20000');
  });

  test('去除首尾空白', () {
    expect(p.normalize('  明天开会  '), '明天开会');
  });

  test('保留中文标点用于分句（被 Splitter 处理）', () {
    // 全角逗号/分号/句号已转半角，但中文顿号、感叹号保留
    expect(p.normalize('开会！'), '开会!');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/preprocessor_test.dart`
Expected: FAIL — 类型不存在

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/parser/preprocessor.dart`:
```dart
import '../../constants/smart_entry_keywords.dart';

/// 文本预处理：全半角统一、中文数字/单位词转阿拉伯数字、去首尾空白。
///
/// 不负责分句（交给 Splitter）。中文数字转换只覆盖高频金额场景，
/// 复杂长串数字交给云端兜底。
class Preprocessor {
  const Preprocessor();

  String normalize(String input) {
    var s = input.trim();
    s = _fullWidthToHalf(s);
    s = _convertChineseNumber(s);
    s = _convertUnitWords(s);
    return s;
  }

  /// 全角字符（含标点）转半角。
  String _fullWidthToHalf(String s) {
    final buf = StringBuffer();
    for (final code in s.runes) {
      if (code == 0x3000) {
        buf.write(' ');
      } else if (code >= 0xFF01 && code <= 0xFF5E) {
        buf.write(String.fromCharCode(code - 0xFEE0));
      } else {
        buf.write(String.fromCharCode(code));
      }
    }
    return buf.toString();
  }

  /// 中文数字（金额高频）转阿拉伯。仅匹配连读的中数字串。
  String _convertChineseNumber(String s) {
    return s.replaceAllMapped(
      RegExp(r'[零一二三四五六七八九十百千万两]+'),
      (m) {
        final n = chineseNumberToArabic(m[0]!);
        return n == null ? m[0]! : n.toString();
      },
    );
  }

  /// 1k/1w/1K/1W → 1000/10000。
  String _convertUnitWords(String s) {
    return s.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*([kKwW])'),
      (m) {
        final num n = double.parse(m[1]!);
        final mul = (m[2]!.toLowerCase() == 'k') ? 1000 : 10000;
        final v = n * mul;
        return v == v.toInt() ? v.toInt().toString() : v.toString();
      },
    );
  }
}
```

注意：`chineseNumberToArabic` 在 Task 4（关键词表）里定义。为避免编译错误，本 Task 与 Task 4 紧邻实现，或先在 Task 4 实现。**实现顺序约定：先做 Task 4（关键词表，含 `chineseNumberToArabic`），再做本 Task 2。** 下文 Task 4 在前。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/preprocessor_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/parser/preprocessor.dart test/smart_entry/preprocessor_test.dart
git commit -m "feat(smart-entry): add text preprocessor"
```

---

## Task 3: 分句 Splitter

**Files:**
- Create: `lib/features/smart_entry/parser/splitter.dart`
- Test: `test/smart_entry/splitter_test.dart`

- [ ] **Step 1: 写失败测试**

`test/smart_entry/splitter_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/parser/splitter.dart';

void main() {
  const s = Splitter();

  test('按逗号分句', () {
    expect(s.split('明天3点开会,午餐花了25'), ['明天3点开会', '午餐花了25']);
  });

  test('多种分隔符混合', () {
    expect(s.split('开会；下班买水果。回家'), ['开会', '下班买水果', '回家']);
  });

  test('换行分句', () {
    expect(s.split('明天开会\n买咖啡'), ['明天开会', '买咖啡']);
  });

  test('连续分隔符合并空段', () {
    expect(s.split('开会，，买咖啡'), ['开会', '买咖啡']);
  });

  test('空输入返回空列表', () {
    expect(s.split(''), isEmpty);
    expect(s.split('   '), isEmpty);
  });

  test('去每段首尾空白', () {
    expect(s.split(' 开会 , 买咖啡 '), ['开会', '买咖啡']);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/splitter_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/parser/splitter.dart`:
```dart
/// 按 ，, ；; 。. 换行 将多句输入拆成段。
/// 已假定输入经过 Preprocessor（全角标点已转半角）。
class Splitter {
  const Splitter();

  static final _sep = RegExp(r'[,\s,;；.。]+');

  List<String> split(String input) {
    if (input.trim().isEmpty) return const [];
    return input
        .split(_sep)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/splitter_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/parser/splitter.dart test/smart_entry/splitter_test.dart
git commit -m "feat(smart-entry): add sentence splitter"
```

---

## Task 4: 关键词与中文数字词表

**Files:**
- Create: `lib/features/smart_entry/constants/smart_entry_keywords.dart`
- Test: `test/smart_entry/preprocessor_test.dart`（已在 Task 2 覆盖 `chineseNumberToArabic`，这里补一组直接测函数）

> **注意：本 Task 必须在 Task 2（Preprocessor）之前实现**，因为 Preprocessor 依赖 `chineseNumberToArabic`。调整执行顺序为：Task1 → Task4 → Task2 → Task3 → Task5。

- [ ] **Step 1: 写失败测试**

新建 `test/smart_entry/keywords_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/constants/smart_entry_keywords.dart';

void main() {
  group('chineseNumberToArabic', () {
    test('单字', () {
      expect(chineseNumberToArabic('五'), 5);
      expect(chineseNumberToArabic('十'), 10);
    });
    test('十位', () {
      expect(chineseNumberToArabic('二十五'), 25);
      expect(chineseNumberToArabic('三十'), 30);
      expect(chineseNumberToArabic('十八'), 18);
    });
    test('百位', () {
      expect(chineseNumberToArabic('一百二十'), 120);
      expect(chineseNumberToArabic('两百'), 200);
    });
    test('万位', () {
      expect(chineseNumberToArabic('两万三'), 23000);
      expect(chineseNumberToArabic('一万'), 10000);
    });
    test('无法解析返回 null', () {
      expect(chineseNumberToArabic('abc'), isNull);
    });
  });

  group('动词词表', () {
    test('消费动词命中', () {
      expect(expenseVerbs.any((w) => '花了'.contains(w)), isTrue);
    });
    test('任务动词命中', () {
      expect(taskVerbs.any((w) => '明天开会'.contains(w)), isTrue);
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/keywords_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/constants/smart_entry_keywords.dart`:
```dart
/// 智能录入解析用的词表与中文数字转换。详见 spec §5.2。
library;

// ===== 中文数字转阿拉伯 =====

const _digit = {
  '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
  '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
};

/// 将连读中文数字（金额高频场景）转阿拉伯整数。
/// 无法解析返回 null。仅覆盖十万以内常用写法，复杂长串交给云端。
int? chineseNumberToArabic(String s) {
  if (s.isEmpty) return null;
  if (RegExp(r'^[0-9]+$').hasMatch(s)) return int.tryParse(s);

  int? total;
  int section = 0;
  int? current;

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
      total = (total ?? 0) + section * 10000;
      section = 0;
      return true;
    }
    final d = _digit[ch];
    if (d == null) return false;
    if (current != null) {
      // 连续数字（如"二五"），按多位拼接
      current = current * 10 + d;
    } else {
      current = d;
    }
    return true;
  }

  for (final ch in s.runes.map(String.fromCharCode)) {
    if (!handleChar(ch)) return null;
  }
  section += current ?? 0;
  return (total ?? 0) + section;
}

// ===== 动词词表（事项/账单判定） =====

/// 出现则强倾向账单。
const expenseVerbs = <String>['花了', '买了', '消费', '支出', '付款', '付了', '充值'];

/// 出现则强倾向收入账单。
const incomeVerbs = <String>['工资', '收入', '收到', '退款', '报销', '奖金'];

/// 出现则倾向事项。
const taskVerbs = <String>['开会', '提醒', '记得', '别忘了', '办', '办理', '交', '预约', '带'];

// ===== 金额/单位 =====

/// 金额正则：匹配带或不带货币符号的数字（含小数）。捕获组 1 为纯数字串。
final amountPattern = RegExp(r'(?:[￥¥]|RMB|人民币)?\s*(\d+(?:\.\d+)?)');

/// 货币符号集合，用于判定是否有金额上下文。
const currencyMarkers = ['￥', '¥', 'RMB', '人民币', '元', '块', '毛', '角', '块'];

// ===== 分类关键词（用于 categoryGuess 文本抽取，匹配分类 id 交给 CategoryMatcher） =====

/// 关键词 → categoryGuess 文本（供 CategoryMatcher 用本地分类表二次匹配 id）。
const categoryKeywords = <String, String>{
  '早餐': '餐饮', '午餐': '餐饮', '晚餐': '餐饮', '外卖': '餐饮', '吃饭': '餐饮',
  '咖啡': '餐饮', '奶茶': '餐饮',
  '打车': '交通', '地铁': '交通', '公交': '交通', '加油': '交通', '停车': '交通',
  '工资': '工资', '奖金': '工资', '报销': '工资',
  '话费': '通讯', '网费': '通讯', '流量': '通讯',
  '房租': '住房', '水电': '住房', '物业': '住房',
  '电影': '娱乐', '游戏': '娱乐', '会员': '娱乐',
  '续费': '订阅', '订阅': '订阅',
};
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/keywords_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/constants/smart_entry_keywords.dart test/smart_entry/keywords_test.dart
git commit -m "feat(smart-entry): add keyword tables and chinese number parser"
```

---

## Task 5: 本地规则引擎 LocalRuleEngine

**Files:**
- Create: `lib/features/smart_entry/parser/local_rule_engine.dart`
- Test: `test/smart_entry/local_rule_engine_test.dart`

这是切片1的测试重点。先实现一个固定 `now` 的构造，便于测试。

- [ ] **Step 1: 写失败测试**

`test/smart_entry/local_rule_engine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/parser/local_rule_engine.dart';

void main() {
  // 固定"现在"为 2026-06-19 10:00（周五），保证相对时间测试稳定。
  final now = DateTime(2026, 6, 19, 10);
  final engine = LocalRuleEngine(now: now);

  test('消费动词+金额 → 支出账单', () {
    final items = engine.parse('午餐花了25');
    expect(items, hasLength(1));
    final item = items.single;
    expect(item.kind, DraftKind.bill);
    expect(item.amountCents, 2500);
    expect(item.amountType, DraftAmountType.expense);
    expect(item.categoryGuess, '餐饮');
    expect(item.confidence, greaterThan(0.6));
  });

  test('任务动词 → 事项', () {
    final items = engine.parse('明天3点开会');
    expect(items, hasLength(1));
    final item = items.single;
    expect(item.kind, DraftKind.lifeItem);
    expect(item.time, DateTime(2026, 6, 20, 15));
    expect(item.amountCents, isNull);
  });

  test('收入动词+金额 → 收入账单', () {
    final items = engine.parse('工资到账5000');
    final item = items.single;
    expect(item.kind, DraftKind.bill);
    expect(item.amountType, DraftAmountType.income);
    expect(item.amountCents, 500000);
  });

  test('仅金额无动词 → 默认支出账单', () {
    final items = engine.parse('25');
    final item = items.single;
    expect(item.kind, DraftKind.bill);
    expect(item.amountType, DraftAmountType.expense);
  });

  test('重复规则 → 事项', () {
    final items = engine.parse('每月15号交房租');
    final item = items.single;
    expect(item.kind, DraftKind.lifeItem);
    expect(item.repeatRule, isNotNull);
  });

  test('完全无法解析 → 返回空', () {
    expect(engine.parse('随便一句话没有任何信息'), isEmpty);
  });

  test('相对时间：后天', () {
    final items = engine.parse('后天下午开会');
    final item = items.single;
    expect(item.time.day, 21); // 6/19 + 2
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/local_rule_engine_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/parser/local_rule_engine.dart`:
```dart
import '../../constants/smart_entry_keywords.dart';
import '../models/draft_item.dart';
import 'preprocessor.dart';
import 'splitter.dart';

/// 本地规则引擎：把单段文本解析成 0..n 个 DraftItem。
///
/// 四类抽取：金额、时间、分类、事项/账单判定（spec §5.2）。
/// 通过 `now` 注入当前时间，保证可测。
class LocalRuleEngine {
  LocalRuleEngine({DateTime? now, DraftSource source = DraftSource.nl})
    : now = now ?? DateTime.now(),
      defaultSource = source;

  final DateTime now;
  final DraftSource defaultSource;

  static const _pre = Preprocessor();
  static const _split = Splitter();

  /// 解析整段（可能多句）输入，返回多个 DraftItem。
  List<DraftItem> parseAll(String input) {
    final norm = _pre.normalize(input);
    final segments = _split.split(norm);
    return [
      for (final seg in segments) ...parse(seg),
    ];
  }

  /// 解析单段（一句），返回 0..n 个 DraftItem（一句通常 1 个）。
  List<DraftItem> parse(String segment) {
    final seg = segment.trim();
    if (seg.isEmpty) return const [];

    final amount = _extractAmount(seg);
    final time = _extractTime(seg);
    final categoryGuess = _extractCategory(seg);
    final repeatRule = _extractRepeatRule(seg);
    final kind = _judgeKind(seg, amount, repeatRule);

    if (kind == null) return const [];

    final isExpense = expenseVerbs.any(seg.contains);
    final isIncome = incomeVerbs.any(seg.contains);

    final title = _extractTitle(seg);

    final amountType = kind == DraftKind.bill
        ? (isIncome
              ? DraftAmountType.income
              : DraftAmountType.expense)
        : (isIncome
              ? DraftAmountType.income
              : (amount == null
                    ? DraftAmountType.none
                    : DraftAmountType.expense));

    // 置信度粗算
    double conf = 0.5;
    if (kind == DraftKind.bill && amount != null) conf += 0.3;
    if (time != null) conf += 0.15;
    if (categoryGuess != null) conf += 0.1;
    if (kind == DraftKind.lifeItem &&
        (taskVerbs.any(seg.contains) || repeatRule != null)) {
      conf += 0.25;
    }

    final notes = <String>[];
    if (kind == DraftKind.bill && amount == null) {
      notes.add('未识别到金额，请补充');
    }
    if (time == null) notes.add('未识别到时间，默认为现在');

    return [
      DraftItem(
        kind: kind,
        title: title,
        amountCents: amount,
        amountType: amountType,
        time: time ?? now,
        remindTime: null,
        repeatRule: kind == DraftKind.lifeItem ? repeatRule : null,
        categoryId: null,
        categoryGuess: categoryGuess,
        confidence: conf.clamp(0.0, 0.99),
        parseNotes: notes,
        source: defaultSource,
      ),
    ];
  }

  int? _extractAmount(String seg) {
    final m = amountPattern.firstMatch(seg);
    if (m == null) return null;
    final n = double.tryParse(m.group(1)!);
    if (n == null) return null;
    return (n * 100).round(); // 元 → 分
  }

  DateTime? _extractTime(String seg) {
    // 绝对日期：2026-06-19 / 2026/6/19 / 6月19日
    final abs = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    ).firstMatch(seg);
    if (abs != null) {
      final d = DateTime(
        int.parse(abs.group(1)!),
        int.parse(abs.group(2)!),
        int.parse(abs.group(3)!),
      );
      return _withTime(d, seg);
    }
    final cnDate = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(seg);
    if (cnDate != null) {
      final d = DateTime(
        now.year,
        int.parse(cnDate.group(1)!),
        int.parse(cnDate.group(2)!),
      );
      return _withTime(d, seg);
    }

    // 相对日期
    int? addDays;
    if (seg.contains('今天')) addDays = 0;
    else if (seg.contains('明天')) addDays = 1;
    else if (seg.contains('后天')) addDays = 2;
    else if (seg.contains('大后天')) addDays = 3;
    if (addDays != null) {
      final d = now.add(Duration(days: addDays));
      return _withTime(DateTime(d.year, d.month, d.day), seg);
    }

    // 仅时间无日期 → 今天
    return _maybeTimeOnly(seg);
  }

  DateTime _withTime(DateTime day, String seg) {
    final t = RegExp(r'(\d{1,2})\s*[点:：时]\s*(\d{1,2})?').firstMatch(seg);
    if (t != null) {
      final h = int.parse(t.group(1)!);
      final min = t.group(2) == null ? 0 : int.parse(t.group(2)!);
      return DateTime(day.year, day.month, day.day, h, min);
    }
    if (seg.contains('上午')) return DateTime(day.year, day.month, day.day, 9);
    if (seg.contains('下午')) return DateTime(day.year, day.month, day.day, 14);
    if (seg.contains('晚上') || seg.contains('晚')) {
      return DateTime(day.year, day.month, day.day, 19);
    }
    return day;
  }

  DateTime? _maybeTimeOnly(String seg) {
    final t = RegExp(r'(\d{1,2})\s*[点:：时]\s*(\d{1,2})?').firstMatch(seg);
    if (t == null) return null;
    final h = int.parse(t.group(1)!);
    final min = t.group(2) == null ? 0 : int.parse(t.group(2)!);
    return DateTime(now.year, now.month, now.day, h, min);
  }

  String? _extractRepeatRule(String seg) {
    if (seg.contains('每天') || seg.contains('每日')) return 'daily';
    if (seg.contains('每周') || seg.contains('每星期')) return 'weekly';
    if (RegExp(r'每月\d{1,2}号?').hasMatch(seg) ||
        RegExp(r'每月\d{1,2}日').hasMatch(seg)) {
      return 'monthly';
    }
    if (seg.contains('每年')) return 'yearly';
    return null;
  }

  String? _extractCategory(String seg) {
    for (final entry in categoryKeywords.entries) {
      if (seg.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _extractTitle(String seg) {
    // 去掉金额、时间、单位、动词，剩余中文片段作为标题
    var t = seg
        .replaceAll(amountPattern, '')
        .replaceAll(RegExp(r'\d{1,2}\s*[点:：时]\s*\d{0,2}'), '')
        .replaceAll(RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}'), '')
        .replaceAll(RegExp(r'\d{1,2}月\d{1,2}日'), '');
    for (final w in [
      ...expenseVerbs,
      ...incomeVerbs,
      ...currencyMarkers,
      '今天',
      '明天',
      '后天',
      '大后天',
      '上午',
      '下午',
      '晚上',
      '每天',
      '每周',
      '每月',
      '每年',
    ]) {
      t = t.replaceAll(w, '');
    }
    t = t.replaceAll(RegExp(r'\s+'), '').trim();
    return t.isEmpty ? '未命名' : t;
  }

  DraftKind? _judgeKind(String seg, int? amount, String? repeatRule) {
    final hasExpense = expenseVerbs.any(seg.contains) ||
        currencyMarkers.any(seg.contains);
    final hasIncome = incomeVerbs.any(seg.contains);
    final hasTask = taskVerbs.any(seg.contains);

    if ((hasExpense || hasIncome) && amount != null) {
      return DraftKind.bill;
    }
    if (hasTask || repeatRule != null) {
      return DraftKind.lifeItem;
    }
    if (amount != null) {
      return DraftKind.bill; // 仅金额默认支出账单
    }
    if (hasExpense || hasIncome) {
      return DraftKind.bill; // 有消费/收入动词即便金额没抓到也判账单
    }
    return null; // 都不含 → 交给云端兜底
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/local_rule_engine_test.dart`
Expected: PASS（7 用例）

如有失败，按失败信息修正正则/词表，再跑直到全过。

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/parser/local_rule_engine.dart test/smart_entry/local_rule_engine_test.dart
git commit -m "feat(smart-entry): add local rule engine with amount/time/category/kind extraction"
```

---

## Task 6: 管道编排 SmartEntryParser（仅本地分支）

**Files:**
- Create: `lib/features/smart_entry/parser/smart_entry_parser.dart`
- Test: 在 `local_rule_engine_test.dart` 同目录加 `smart_entry_parser_test.dart`

本 Task 只编排预处理→分句→本地规则→装配 EntryDraft，云端分支在切片7接入（留 TODO 钩子但先返回本地结果）。

- [ ] **Step 1: 写失败测试**

`test/smart_entry/smart_entry_parser_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/parser/smart_entry_parser.dart';

void main() {
  final parser = SmartEntryParser.forTest(now: DateTime(2026, 6, 19, 10));

  test('一句话拆出事项+账单', () {
    final draft = parser.parse('明天3点开会,午餐花了25');
    expect(draft.items, hasLength(2));
    expect(draft.items.any((i) => i.kind == DraftKind.lifeItem), isTrue);
    expect(draft.items.any((i) => i.kind == DraftKind.bill), isTrue);
    expect(draft.source, DraftSource.nl);
    expect(draft.rawInput, '明天3点开会,午餐花了25');
  });

  test('空输入 → 空 draft', () {
    final draft = parser.parse('');
    expect(draft.isEmpty, isTrue);
  });

  test('保留 ocrFullText', () {
    final draft = parser.parse(
      '合计 25.00',
      source: DraftSource.ocr,
      ocrFullText: '商店\n合计 25.00',
    );
    expect(draft.ocrFullText, '商店\n合计 25.00');
    expect(draft.source, DraftSource.ocr);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/smart_entry_parser_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/parser/smart_entry_parser.dart`:
```dart
import '../models/draft_item.dart';
import 'local_rule_engine.dart';

/// 智能录入解析管道入口。spec §5.1。
///
/// 当前实现：预处理 → 分句 → 本地规则引擎 → 装配 EntryDraft。
/// 云端兜底分支在切片7接入（见 _maybeCloudEnhance 钩子）。
class SmartEntryParser {
  SmartEntryParser({DateTime? now}) : _engine = LocalRuleEngine(now: now);

  SmartEntryParser.forTest({required DateTime now})
    : _engine = LocalRuleEngine(now: now);

  final LocalRuleEngine _engine;

  /// 解析文本输入。
  /// [source] 标记数据来源；[ocrFullText] 仅 OCR 来源携带原文。
  Future<EntryDraft> parse(
    String input, {
    DraftSource source = DraftSource.nl,
    String? ocrFullText,
  }) async {
    final items = _engine.parseAll(input);
    // 切片7在此处插入：若存在低置信项或空段且云开启，调 CloudParser 兜底。
    await _maybeCloudEnhance(items, input);
    return EntryDraft(
      items: items,
      source: source,
      rawInput: input,
      ocrFullText: ocrFullText,
    );
  }

  /// 云端兜底钩子。切片1返回空实现；切片7实现真正的云端调用。
  Future<void> _maybeCloudEnhance(List<DraftItem> items, String input) async {
    // no-op for now (slice 1). 云端分支在切片7接入。
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/smart_entry_parser_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/parser/smart_entry_parser.dart test/smart_entry/smart_entry_parser_test.dart
git commit -m "feat(smart-entry): add SmartEntryParser pipeline (local-only)"
```

---

## Task 7: 分类匹配服务 CategoryMatcher

**Files:**
- Create: `lib/features/smart_entry/services/category_matcher.dart`
- Test: `test/smart_entry/category_matcher_test.dart`

负责把 `categoryGuess` 文本（"餐饮"）匹配到本地分类 id。账单按 `expense`/`income` 查分类表。

- [ ] **Step 1: 写失败测试**

`test/smart_entry/category_matcher_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/repositories/category_repository.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/services/category_matcher.dart';

void main() {
  late AppDatabase db;
  late CategoryMatcher matcher;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // 内存库会自动播种默认分类。用 CategoryRepository.create 补充自定义分类。
    await CategoryRepository(db).create(name: '咖啡', type: 'expense', icon: 'coffee');
    matcher = CategoryMatcher(db.categoryDao);
  });

  tearDown(() async => db.close());

  test('按文本精确匹配（默认分类已含支出/收入项）', () async {
    // 默认支出分类含“餐饮”类目吗？不一定；用插入的“咖啡”验证。
    final id = await matcher.matchId('咖啡', DraftKind.bill, DraftAmountType.expense);
    expect(id, isNotNull);
  });

  test('不匹配返回 null', () async {
    final id = await matcher.matchId('不存在的分类XYZ', DraftKind.bill, DraftAmountType.expense);
    expect(id, isNull);
  });

  test('收入类型只在 income 分类里找', () async {
    // 默认收入分类存在（自动播种）；插入一个 income 自定义验证匹配
    await CategoryRepository(db).create(name: '兼职', type: 'income', icon: 'wallet');
    final id = await matcher.matchId('兼职', DraftKind.bill, DraftAmountType.income);
    expect(id, isNotNull);
    final id2 = await matcher.matchId('咖啡', DraftKind.bill, DraftAmountType.income);
    expect(id2, isNull); // “咖啡”是 expense，不应在 income 里命中
  });
}
```

> 说明：内存库 `AppDatabase.forTesting(NativeDatabase.memory())` 会自动播种默认分类（见 `category_repository_test.dart`），所以不必手动插“餐饮/交通/工资”。用 `CategoryRepository.create()` 补充自定义分类来稳定测试（API 已确认存在，见 `category_repository_test.dart:35-40`）。`matchId` 的第二个参数用 `DraftKind`/`DraftAmountType`（Task 1 定义）。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/category_matcher_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/services/category_matcher.dart`:
```dart
import '../../data/database/daos/category_dao.dart';
import '../models/draft_item.dart';

/// 把 categoryGuess 文本匹配到本地分类表 id。
/// 按 draft 的 kind/amountType 决定查 expense/income/none 分类。spec §5.4。
class CategoryMatcher {
  CategoryMatcher(this._dao);

  final CategoryDao _dao;

  Future<int?> matchId(
    String? guess,
    DraftKind kind,
    DraftAmountType amountType,
  ) async {
    if (guess == null || guess.trim().isEmpty) return null;
    final type = _typeFor(kind, amountType);
    final list = type == null
        ? await _dao.getAll()
        : await _dao.getByType(type);
    for (final c in list) {
      if (c.name == guess) return c.id;
    }
    return null;
  }

  String? _typeFor(DraftKind kind, DraftAmountType amountType) {
    if (kind == DraftKind.bill) {
      return amountType == DraftAmountType.income ? 'income' : 'expense';
    }
    // 事项分类按金额类型走
    switch (amountType) {
      case DraftAmountType.income:
        return 'income';
      case DraftAmountType.expense:
        return 'expense';
      case DraftAmountType.none:
        return null; // 无金额事项不限类型
    }
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/category_matcher_test.dart`
Expected: PASS（如 companion 语法报错，参照现有 `category_repository_test.dart` 修正 setUp 写法）

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/services/category_matcher.dart test/smart_entry/category_matcher_test.dart
git commit -m "feat(smart-entry): add CategoryMatcher for guess-to-id resolution"
```

---

## Task 8: 草稿落库 Provider（接现有 Notifier / Repository）

**Files:**
- Create: `lib/features/smart_entry/providers/smart_entry_providers.dart`

把确认后的 DraftItem 列表分发到 `lifeItemNotifierProvider.create()` / `billRecordRepository.create()`。先匹配分类 id，再按 kind 调对应落库方法。事项走 Notifier（含提醒调度），账单走 Repository。

- [ ] **Step 1: 写实现（含 provider 定义，无独立测试文件，由组件测试覆盖）**

`lib/features/smart_entry/providers/smart_entry_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../models/draft_item.dart';
import '../parser/smart_entry_parser.dart';
import '../services/category_matcher.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/database/daos/category_dao.dart';

final smartEntryParserProvider = Provider<SmartEntryParser>((ref) {
  return SmartEntryParser();
});

final categoryMatcherProvider = Provider<CategoryMatcher>((ref) {
  return CategoryMatcher(CategoryDao(ref.watch(databaseProvider)));
});

/// 草稿落库结果。
class DraftPersistResult {
  DraftPersistResult({required this.saved, required this.failed});
  final List<DraftItem> saved; // 已成功落库（带最终 categoryId）
  final List<DraftItem> failed; // 失败，保留原草稿供用户改后重试
}

/// 把确认后的 DraftItem 列表落库。部分失败不阻断其余。spec §7.3。
///
/// 事项走 lifeItemNotifierProvider.create()（含提醒调度），
/// 账单走 billNotifierProvider.create()（内部确保默认账户，对齐现有 BillEditPage 链路）。
class SmartEntryPersistService {
  SmartEntryPersistService(this._ref);

  final Ref _ref;

  Future<DraftPersistResult> persist(List<DraftItem> items) async {
    final matcher = _ref.read(categoryMatcherProvider);
    final lifeNotifier = _ref.read(lifeItemNotifierProvider.notifier);
    final billNotifier = _ref.read(billNotifierProvider.notifier);

    final saved = <DraftItem>[];
    final failed = <DraftItem>[];

    for (final item in items) {
      try {
        final categoryId = item.categoryId ??
            await matcher.matchId(item.categoryGuess, item.kind, item.amountType);

        if (item.kind == DraftKind.lifeItem) {
          await lifeNotifier.create({
            'title': item.title,
            'categoryId': categoryId,
            'amount': item.amountCents,
            'amountType': item.amountType.value == 'none'
                ? 'none'
                : item.amountType.value,
            'dueTime': item.time,
            'remindTime': item.remindTime,
            'repeatRule': item.repeatRule,
          });
        } else {
          // BillNotifier.create 会自动解析默认账户，不传 accountId。
          await billNotifier.create(
            title: item.title,
            amount: item.amountCents ?? 0,
            amountType: item.amountType.value == 'none'
                ? 'expense'
                : item.amountType.value,
            categoryId: categoryId,
            billTime: item.time,
          );
        }
        saved.add(item.copyWith(categoryId: categoryId));
      } catch (e) {
        failed.add(item);
      }
    }
    return DraftPersistResult(saved: saved, failed: failed);
  }
}

final smartEntryPersistProvider =
    Provider<SmartEntryPersistService>((ref) {
  return SmartEntryPersistService(ref);
});
```

> 注意：provider 名称以现有代码为准——`billNotifierProvider` / `lifeItemNotifierProvider`（见 `lib/features/bill/providers/bill_providers.dart` 与 `lib/features/life_item/providers/life_item_providers.dart`）。`BillNotifier.create()` 入参与 `LifeItemNotifier.create()` 的 Map 入参对齐各自源文件。事项的 Map 字段对齐 `life_item_providers.dart:66-77`；账单用命名参数对齐 `bill_providers.dart:52-62`。

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/features/smart_entry/providers/smart_entry_providers.dart`
Expected: 无 error（warning 可暂忽略，后续清理）

- [ ] **Step 3: 提交**

```bash
git add lib/features/smart_entry/providers/smart_entry_providers.dart
git commit -m "feat(smart-entry): add persist service wiring drafts to existing repos"
```

---

## Task 9: 草稿卡片组件 DraftItemCard

**Files:**
- Create: `lib/features/smart_entry/widgets/draft_item_card.dart`
- Test: `test/smart_entry/draft_item_card_test.dart`

- [ ] **Step 1: 写失败测试**

`test/smart_entry/draft_item_card_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/widgets/draft_item_card.dart';

void main() {
  testWidgets('展示标题与金额，低置信有警告标识', (tester) async {
    final item = DraftItem(
      kind: DraftKind.bill,
      title: '午餐',
      amountCents: 2500,
      amountType: DraftAmountType.expense,
      time: DateTime(2026, 6, 19, 12),
      source: DraftSource.nl,
      confidence: 0.5,
      parseNotes: const ['未识别到金额'],
    );
    DraftItem? edited;
    bool deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraftItemCard(
            item: item,
            onChanged: (i) => edited = i,
            onDeleted: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('¥25.00'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget); // 低置信
    expect(find.text('未识别到金额'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('draft-card-delete')));
    await tester.pump();
    expect(deleted, isTrue);
  });

  testWidgets('高置信无警告', (tester) async {
    final item = DraftItem(
      kind: DraftKind.bill,
      title: '咖啡',
      amountCents: 1500,
      amountType: DraftAmountType.expense,
      time: DateTime(2026, 6, 19, 12),
      source: DraftSource.nl,
      confidence: 0.9,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraftItemCard(
            item: item,
            onChanged: (_) {},
            onDeleted: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/draft_item_card_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/widgets/draft_item_card.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../models/draft_item.dart';

/// 单条草稿卡片。支持 inline 编辑标题、删除。spec §7.2。
class DraftItemCard extends StatelessWidget {
  const DraftItemCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDeleted,
  });

  final DraftItem item;
  final ValueChanged<DraftItem> onChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final low = item.isLowConfidence;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: low ? Colors.orange.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (low)
              Container(
                width: 4,
                color: Colors.orange,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.kind == DraftKind.bill
                              ? Icons.payments_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        if (low)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange,
                            ),
                          ),
                        Expanded(
                          child: TextFormField(
                            initialValue: item.title,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            onChanged: (v) => onChanged(item.copyWith(title: v)),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('draft-card-delete'),
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: onDeleted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _chip(
                          item.amountCents == null
                              ? '无金额'
                              : MoneyFormatter.formatCents(item.amountCents!),
                        ),
                        _chip(_kindLabel()),
                        _chip(_timeLabel()),
                      ],
                    ),
                    if (item.parseNotes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.parseNotes.join('；'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.primary),
    ),
  );

  String _kindLabel() {
    switch (item.amountType) {
      case DraftAmountType.income:
        return '收入';
      case DraftAmountType.expense:
        return '支出';
      case DraftAmountType.none:
        return item.kind == DraftKind.bill ? '支出' : '事项';
    }
  }

  String _timeLabel() {
    final t = item.time;
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
```

> 注意：`MoneyFormatter.formatCents` / `AppColors.surface|primary|primaryLight|textPrimary|textSecondary` 的确切 API 在执行时用 `grep` 确认（`MoneyFormatter` 见 `lib/core/utils/money_formatter.dart`，`AppColors` 见 `lib/core/theme/app_colors.dart`）。若方法名不同（如 `formatYuan`）按实际改。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/draft_item_card_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/widgets/draft_item_card.dart test/smart_entry/draft_item_card_test.dart
git commit -m "feat(smart-entry): add DraftItemCard widget"
```

---

## Task 10: 草稿确认页 SmartEntryConfirmPage + 路由

**Files:**
- Create: `lib/features/smart_entry/pages/smart_entry_confirm_page.dart`
- Modify: `lib/core/router/app_router.dart`（加路由）
- Modify: `test/helpers/test_app.dart`（测试路由加 confirm 页）
- Test: `test/smart_entry/smart_entry_confirm_page_test.dart`

- [ ] **Step 1: 写失败测试**

`test/smart_entry/smart_entry_confirm_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_confirm_page.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  Future<void> pumpConfirm(
    WidgetTester tester, {
    required List<DraftItem> items,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: SmartEntryConfirmPage(
            draft: EntryDraft(
              items: items,
              source: DraftSource.nl,
              rawInput: '测试',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('渲染所有卡片 + 保存全部按钮', (tester) async {
    await pumpConfirm(
      tester,
      items: [
        DraftItem(
          kind: DraftKind.bill, title: '午餐', amountCents: 2500,
          amountType: DraftAmountType.expense,
          time: DateTime(2026, 6, 19), source: DraftSource.nl, confidence: 0.9,
        ),
        DraftItem(
          kind: DraftKind.lifeItem, title: '开会',
          amountCents: null, amountType: DraftAmountType.none,
          time: DateTime(2026, 6, 20), source: DraftSource.nl, confidence: 0.9,
        ),
      ],
    );
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('开会'), findsOneWidget);
    expect(find.text('保存全部 2 条'), findsOneWidget);
  });

  testWidgets('删除一条后计数更新', (tester) async {
    await pumpConfirm(
      tester,
      items: [
        DraftItem(
          kind: DraftKind.bill, title: '咖啡', amountCents: 1500,
          amountType: DraftAmountType.expense,
          time: DateTime(2026, 6, 19), source: DraftSource.nl, confidence: 0.9,
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('draft-card-delete')));
    await tester.pump();
    expect(find.textContaining('没识别到'), findsOneWidget); // 进入空态
  });

  testWidgets('空态显示引导', (tester) async {
    await pumpConfirm(tester, items: const []);
    expect(find.textContaining('没识别到'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/smart_entry_confirm_page_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/pages/smart_entry_confirm_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/draft_item.dart';
import '../providers/smart_entry_providers.dart';
import '../widgets/draft_item_card.dart';

/// 草稿确认页。所有入口解析后的唯一汇聚点。spec §7。
class SmartEntryConfirmPage extends ConsumerStatefulWidget {
  const SmartEntryConfirmPage({super.key, required this.draft});

  /// 通过路由 extra 传入。
  final EntryDraft draft;

  @override
  ConsumerState<SmartEntryConfirmPage> createState() =>
      _SmartEntryConfirmPageState();
}

class _SmartEntryConfirmPageState extends ConsumerState<SmartEntryConfirmPage> {
  late List<DraftItem> _items = List.of(widget.draft.items);
  bool _saving = false;

  void _onChanged(int i, DraftItem item) => _items[i] = item;
  void _onDelete(int i) => setState(() => _items.removeAt(i));

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final result = await ref
        .read(smartEntryPersistProvider)
        .persist(_items);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.failed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 ${result.saved.length} 条')),
      );
      context.pop();
    } else {
      setState(() => _items = result.failed); // 保留失败项供重试
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('部分保存失败 ${result.failed.length} 条，请核对')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('解析结果'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _items.isEmpty || _saving ? null : _saveAll,
          ),
        ],
      ),
      body: _items.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                if (widget.draft.rawInput.isNotEmpty)
                  _SourceBanner(draft: widget.draft),
                for (var i = 0; i < _items.length; i++)
                  DraftItemCard(
                    key: ValueKey('draft-$i'),
                    item: _items[i],
                    onChanged: (item) => _onChanged(i, item),
                    onDeleted: () => _onDelete(i),
                  ),
              ],
            ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _saveAll,
                  child: Text(_saving ? '保存中…' : '保存全部 ${_items.length} 条'),
                ),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sentiment_dissatisfied, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('没识别到可记录的内容'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/items/new'),
            child: const Text('手动新建事项'),
          ),
        ],
      ),
    );
  }
}

class _SourceBanner extends StatelessWidget {
  const _SourceBanner({required this.draft});
  final EntryDraft draft;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = const {
      DraftSource.nl: '快速输入',
      DraftSource.ocr: '识图记账',
      DraftSource.share: '来自分享',
      DraftSource.voice: '语音输入',
    }[draft.source];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('来自：$sourceLabel', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(draft.rawInput, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 加路由**

修改 `lib/core/router/app_router.dart`，在 `ShellRoute.routes` 列表里（与 `/items`、`/bills` 同级，全屏无底部栏）顶部新增：
```dart
GoRoute(
  path: '/smart-entry/confirm',
  builder: (context, state) {
    final draft = state.extra as EntryDraft;
    return SmartEntryConfirmPage(draft: draft);
  },
),
```
并在文件顶部 import：
```dart
import '../../features/smart_entry/models/draft_item.dart';
import '../../features/smart_entry/pages/smart_entry_confirm_page.dart';
```

同步修改 `test/helpers/test_app.dart` 的 `_createTestRouter()`，在 ShellRoute.routes 里加同一条 `/smart-entry/confirm` 路由（测试用 `MaterialApp(home:)` 直接挂页则不必改路由，本 Task 测试用直接挂页方式，故 test_app 可暂不改；Task 12 加输入页跳转测试时再补）。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/smart_entry/smart_entry_confirm_page_test.dart`
Expected: PASS（3 用例）

- [ ] **Step 6: 提交**

```bash
git add lib/features/smart_entry/pages/smart_entry_confirm_page.dart lib/core/router/app_router.dart test/smart_entry/smart_entry_confirm_page_test.dart
git commit -m "feat(smart-entry): add draft confirm page and route"
```

---

## Task 11: 快速输入页 SmartEntryInputPage + 接入首页 FAB

**Files:**
- Create: `lib/features/smart_entry/pages/smart_entry_input_page.dart`
- Modify: `lib/features/home/widgets/quick_create_sheet.dart`（顶部加"智能输入"入口）
- Modify: `lib/core/router/app_router.dart`（加 `/smart-entry/input` 路由）
- Test: `test/smart_entry/smart_entry_input_page_test.dart`

- [ ] **Step 1: 写失败测试**

`test/smart_entry/smart_entry_input_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_input_page.dart';

void main() {
  testWidgets('输入文本后点解析按钮跳转确认页（显示解析结果标题）', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SmartEntryInputPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('smart-entry-input-field')),
      '午餐花了25',
    );
    await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
    await tester.pumpAndSettle();

    // 跳到确认页，AppBar 标题为"解析结果"
    expect(find.text('解析结果'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/smart_entry_input_page_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/pages/smart_entry_input_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/draft_item.dart';
import '../providers/smart_entry_providers.dart';

/// 快速输入页。spec §6.1。
class SmartEntryInputPage extends ConsumerStatefulWidget {
  const SmartEntryInputPage({super.key});

  @override
  ConsumerState<SmartEntryInputPage> createState() =>
      _SmartEntryInputPageState();
}

class _SmartEntryInputPageState extends ConsumerState<SmartEntryInputPage> {
  final _controller = TextEditingController();
  bool _parsing = false;

  Future<void> _parse() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _parsing = true);
    final parser = ref.read(smartEntryParserProvider);
    final draft = await parser.parse(text, source: DraftSource.nl);
    if (!mounted) return;
    setState(() => _parsing = false);
    context.push('/smart-entry/confirm', extra: draft);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智能输入')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '试着用一句话描述，例如：',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text('“明天3点开会，午餐花了25”'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('smart-entry-input-field'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入要记录的事项或账单…',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('smart-entry-parse-btn'),
              icon: const Icon(Icons.auto_awesome),
              label: Text(_parsing ? '解析中…' : '解析'),
              onPressed: _parsing ? null : _parse,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 接入首页与路由**

`lib/core/router/app_router.dart` 加：
```dart
GoRoute(
  path: '/smart-entry/input',
  builder: (context, state) => const SmartEntryInputPage(),
),
```
顶部 import：
```dart
import '../../features/smart_entry/pages/smart_entry_input_page.dart';
```

修改 `lib/features/home/widgets/quick_create_sheet.dart`：在 `_QuickCreateSheet` 的 `Column` 里、`GridView.count` 之前插入一个"智能输入"横幅卡片：
```dart
Container(
  margin: const EdgeInsets.only(bottom: 12),
  child: InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => onNavigate('/smart-entry/input'),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('智能输入', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('一句话 / 拍照 / 语音记录', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.primary),
        ],
      ),
    ),
  ),
),
```

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/smart_entry/smart_entry_input_page_test.dart`
Expected: PASS

Run: `flutter analyze lib/features/smart_entry lib/features/home/widgets/quick_create_sheet.dart lib/core/router/app_router.dart`
Expected: 无 error

- [ ] **Step 6: 提交**

```bash
git add lib/features/smart_entry/pages/smart_entry_input_page.dart lib/features/home/widgets/quick_create_sheet.dart lib/core/router/app_router.dart test/smart_entry/smart_entry_input_page_test.dart
git commit -m "feat(smart-entry): add quick input page and wire into home FAB"
```

> 至此切片1-3（MVP）完成：可在首页点"智能输入"→ 输入文本 → 确认页 → 落库，纯本地零依赖。

---

## Task 12: 依赖声明（识图/分享/语音/Key/http）

**Files:**
- Modify: `pubspec.yaml`

后续切片（4/5/6/7）需要的新依赖一次声明，避免反复改 pubspec。

- [ ] **Step 1: 编辑 pubspec.yaml**

在 `dependencies:` 下新增（版本用项目已有的 `flutter pub add` 时取最新稳定版，执行时按 pub 给的为准）：
```yaml
  google_mlkit_text_recognition: ^0.14.0
  image_picker: ^1.1.0
  receive_sharing_intent: ^1.8.0
  speech_to_text: ^6.6.0
  flutter_secure_storage: ^9.2.0
  http: ^1.2.0
```

- [ ] **Step 2: 安装并验证编译**

Run: `flutter pub get`
Expected: 成功，无版本冲突

Run: `flutter analyze`
Expected: 无新增 error（已有 warning 可忽略）

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add mlkit/image_picker/sharing/speech/secure_storage/http"
```

> 若 `flutter pub get` 报版本冲突，使用 dart-resolve-package-conflicts skill 解决，再提交。

---

## Task 13: OCR 服务封装 OcrService

**Files:**
- Create: `lib/features/smart_entry/services/ocr_service.dart`
- Test: `test/smart_entry/ocr_service_test.dart`（用本地测试图片资源）

OCR 依赖真机/模拟器摄像头，单测只覆盖"输入已识别文本 → 解析"路径，真实 OCR 留手动测试。

- [ ] **Step 1: 写实现（接口先行，便于 mock）**

`lib/features/smart_entry/services/ocr_service.dart`:
```dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 服务封装。spec §6.2。
/// 用 ML Kit 端侧文字识别，输入图片文件返回全文本。
class OcrService {
  OcrService({TextRecognizer? recognizer})
    : _recognizer = recognizer ?? TextRecognizer();

  final TextRecognizer _recognizer;

  Future<String> recognize(File image) async {
    final input = InputImage.fromFile(image);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  Future<void> dispose() => _recognizer.close();
}
```

- [ ] **Step 2: 测试只验"空文本→空 draft"链路（真实识别留手动）**

`test/smart_entry/ocr_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/parser/smart_entry_parser.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';

void main() {
  // 不测真实 OCR（需真机）。这里验 OCR 文本喂给解析管道的正确性。
  final parser = SmartEntryParser.forTest(now: DateTime(2026, 6, 19));

  test('标准小票文本解析出金额', () async {
    const ocrText = '便利店\n合计 25.00\n2026-06-19';
    final draft = await parser.parse(
      ocrText,
      source: DraftSource.ocr,
      ocrFullText: ocrText,
    );
    expect(draft.ocrFullText, ocrText);
    expect(draft.source, DraftSource.ocr);
    // 至少识别到金额 25
    final bill = draft.items.where((i) => i.kind == DraftKind.bill).toList();
    expect(bill, isNotEmpty);
    expect(bill.first.amountCents, 2500);
  });

  test('OCR 空文本 → 空 draft', () async {
    final draft = await parser.parse('', source: DraftSource.ocr, ocrFullText: '');
    expect(draft.isEmpty, isTrue);
  });
}
```

- [ ] **Step 3: 在 LocalRuleEngine 加 OCR 来源特化（识别"合计/实付/Total"优先金额）**

修改 `lib/features/smart_entry/parser/local_rule_engine.dart` 的 `_extractAmount`，在通用 amountPattern 之前先尝试小票关键字：
```dart
int? _extractAmount(String seg) {
  // OCR 特化：优先抓 合计/实付/Total/Amount 后的数字
  final receiptAmount = RegExp(
    r'(?:合计|实付|实收|总额|总金额|Total|Amount|应付款)\s*[:：]?\s*(?:[￥¥]|RMB)?\s*(\d+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(seg);
  final source = seg; // seg 携带 source 不便，此处近似：OCR 文本常含这些词
  if (receiptAmount != null) {
    final n = double.tryParse(receiptAmount.group(1)!);
    if (n != null) return (n * 100).round();
  }
  final m = amountPattern.firstMatch(seg);
  if (m == null) return null;
  final n = double.tryParse(m.group(1)!);
  if (n == null) return null;
  return (n * 100).round();
}
```

> 说明：source 维度差异在 `SmartEntryParser` 层处理——OCR 来源调用时可把全文传入；这里保留通用正则即可，OCR 特化词已在同一函数覆盖。重新跑 `local_rule_engine_test.dart` 确保未破坏既有用例。

Run: `flutter test test/smart_entry/`
Expected: 全 PASS

- [ ] **Step 4: 提交**

```bash
git add lib/features/smart_entry/services/ocr_service.dart lib/features/smart_entry/parser/local_rule_engine.dart test/smart_entry/ocr_service_test.dart
git commit -m "feat(smart-entry): add OcrService and receipt-aware amount extraction"
```

---

## Task 14: OCR 预览面板 + 识图入口接线

**Files:**
- Create: `lib/features/smart_entry/widgets/ocr_preview_panel.dart`
- Modify: `lib/features/smart_entry/pages/smart_entry_input_page.dart`（加📷按钮 → 选图 → OCR → 跳确认页）
- Test: `test/smart_entry/smart_entry_input_page_test.dart`（补充📷按钮存在性）

- [ ] **Step 1: 写实现 OcrPreviewPanel**

`lib/features/smart_entry/widgets/ocr_preview_panel.dart`:
```dart
import 'dart:io';
import 'package:flutter/material.dart';

/// OCR 原图缩略图 + 全文折叠面板。spec §7 / §6.2。
class OcrPreviewPanel extends StatelessWidget {
  const OcrPreviewPanel({super.key, required this.imagePath, required this.fullText});

  final String imagePath;
  final String fullText;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(imagePath), width: 40, height: 40, fit: BoxFit.cover),
      ),
      title: const Text('识图原文', style: TextStyle(fontSize: 13)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.topLeft,
            child: SelectableText(
              fullText.isEmpty ? '（未识别到文字）' : fullText,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 输入页加📷按钮**

修改 `smart_entry_input_page.dart`：在 `FilledButton.icon` 下方加一个 `OutlinedButton` 选图入口，并实现 `_pickAndRecognize`：
```dart
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ocr_service.dart';
// ...

final _ocr = OcrService();

Future<void> _pickAndRecognize() async {
  final picker = ImagePicker();
  final xfile = await picker.pickImage(source: ImageSource.gallery);
  if (xfile == null) return;
  setState(() => _parsing = true);
  try {
    final text = await _ocr.recognize(File(xfile.path));
    final draft = await ref.read(smartEntryParserProvider).parse(
      text,
      source: DraftSource.ocr,
      ocrFullText: text,
    );
    if (!mounted) return;
    context.push('/smart-entry/confirm', extra: draft);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('识别失败，请重试或换个清晰的图片')),
    );
  } finally {
    if (mounted) setState(() => _parsing = false);
  }
}
```
并在按钮区追加：
```dart
const SizedBox(height: 8),
OutlinedButton.icon(
  key: const ValueKey('smart-entry-ocr-btn'),
  icon: const Icon(Icons.photo_camera_outlined),
  label: const Text('拍照 / 选图记账'),
  onPressed: _parsing ? null : _pickAndRecognize,
),
```
在 `dispose()` 里加 `_ocr.dispose();`。

- [ ] **Step 3: 测试📷按钮存在**

在 `smart_entry_input_page_test.dart` 加：
```dart
testWidgets('识图入口存在', (tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: SmartEntryInputPage()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(const ValueKey('smart-entry-ocr-btn')), findsOneWidget);
});
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/smart_entry_input_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/smart_entry/widgets/ocr_preview_panel.dart lib/features/smart_entry/pages/smart_entry_input_page.dart test/smart_entry/smart_entry_input_page_test.dart
git commit -m "feat(smart-entry): add OCR entry from input page and preview panel"
```

> 识图真实识别需真机/模拟器手动验证，加入手动测试清单：拍一张超市小票 → 确认页有金额与商家。

---

## Task 15: 系统分享接入 ShareReceiver（平台抽象 + Android 实现）

**Files:**
- Create: `lib/features/smart_entry/services/share_receiver.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`（intent-filter）
- Modify: `lib/main.dart`（初始化接收分享）
- Test: `test/smart_entry/share_receiver_test.dart`（用 fake 实现测抽象）

- [ ] **Step 1: 写失败测试（测抽象契约，用 fake）**

`test/smart_entry/share_receiver_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/services/share_receiver.dart';

void main() {
  test('ShareReceiver 接口契约：冷启动初始文本 + 热启动 stream', () async {
    final receiver = _FakeShareReceiver(initial: '明天开会');
    expect(await receiver.getInitialSharedText(), '明天开会');
    final captured = <String>[];
    receiver.sharedTextStream.listen(captured.add);
    receiver.simulateNew('午餐花了25');
    await Future.delayed(Duration.zero);
    expect(captured, ['午餐花了25']);
  });
}

class _FakeShareReceiver implements ShareReceiver {
  _FakeShareReceiver({this.initial});
  final String? initial;
  final _controller = StreamController<String>.broadcast();

  @override
  Future<String?> getInitialSharedText async => initial;

  @override
  Stream<String> get sharedTextStream => _controller.stream;

  void simulateNew(String t) => _controller.add(t);
}
```

> 注意：上面用了 `StreamController`，需 `import 'dart:async';`；执行时补全 import。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/share_receiver_test.dart`
Expected: FAIL

- [ ] **Step 3: 写抽象 + Android 实现**

`lib/features/smart_entry/services/share_receiver.dart`:
```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// 平台无关的分享接收抽象。spec §14.2。
/// 本次只实现 Android；iOS 未来启用 Share Extension 后接入 IosShareReceiver。
abstract class ShareReceiver {
  Future<String?> get getInitialSharedText; // 冷启动
  Stream<String> get sharedTextStream; // 热启动
}

class AndroidShareReceiver implements ShareReceiver {
  AndroidShareReceiver();

  @override
  Future<String?> get getInitialSharedText async {
    final files = await ReceiveSharingIntent.getInitialMedia();
    final texts = await ReceiveSharingIntent.getInitialText();
    return texts?.isNotEmpty == true
        ? texts!.first
        : null;
  }

  @override
  Stream<String> get sharedTextStream {
    return ReceiveSharingIntent.getTextStream().where((t) => t.isNotEmpty);
  }
}

/// 用于测试的假实现也可由调用方注入。
class NoopShareReceiver implements ShareReceiver {
  const NoopShareReceiver();
  @override
  Future<String?> get getInitialSharedText async => null;
  @override
  Stream<String> get sharedTextStream => const Stream.empty();
}

final shareReceiverProvider = Provider<ShareReceiver>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidShareReceiver();
  }
  // iOS 分支待 Share Extension 配置后接入；当前用 noop，不阻断编译。
  return const NoopShareReceiver();
});
```

- [ ] **Step 4: 加 AndroidManifest intent-filter**

修改 `android/app/src/main/AndroidManifest.xml`，在 `<activity android:name=".MainActivity" ...>` 标签内、现有 LAUNCHER intent-filter 之后追加：
```xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
```

- [ ] **Step 5: 在应用启动初始化（main.dart 或首页）**

在 `lib/main.dart`（或首页 `initState`）接入冷启动分享。若 main.dart 结构不便，则在 `HomePage` initState 里读初始分享：
```dart
// 在 HomePage 的 ConsumerState initState 末尾（需 ref）：
WidgetsBinding.instance.addPostFrameCallback((_) async {
  final receiver = ref.read(shareReceiverProvider);
  final initial = await receiver.getInitialSharedText;
  if (initial != null && initial.isNotEmpty && mounted) {
    _openShareToConfirm(context, initial);
  }
  // 热启动监听（在 build 里用 ref.listen 也可）
});

// 并在页面持有 StreamSubscription，onNewIntent 到来时跳确认页。
```
> 执行时先读 `lib/main.dart` 与 `home_page.dart` 现有结构，把分享初始化放到最合适处；冷热启动都要处理（spec §6.3）。为最小侵入，建议在 `main.dart` 顶层创建一个 `ShareBootstrap` widget 包裹根 widget。

- [ ] **Step 6: 运行确认通过 + 编译**

Run: `flutter test test/smart_entry/share_receiver_test.dart`
Expected: PASS

Run: `flutter analyze lib/features/smart_entry/services/share_receiver.dart`
Expected: 无 error

- [ ] **Step 7: 提交**

```bash
git add lib/features/smart_entry/services/share_receiver.dart android/app/src/main/AndroidManifest.xml lib/main.dart test/smart_entry/share_receiver_test.dart
git commit -m "feat(smart-entry): add share receiver with android implementation"
```

> 真实分享需真机：从浏览器/微信分享一段文字到 App，确认跳到确认页。加入手动测试清单。

---

## Task 16: 语音输入接入

**Files:**
- Modify: `lib/features/smart_entry/pages/smart_entry_input_page.dart`（加🎤按钮）
- Test: 仅验按钮存在（真实语音需真机）

- [ ] **Step 1: 输入页加🎤按钮**

修改 `smart_entry_input_page.dart`，import 并实现：
```dart
import 'package:speech_to_text/speech_to_text.dart';
// ...

final _speech = SpeechToText();
bool _speechAvailable = false;

Future<void> _initSpeech() async {
  _speechAvailable = await _speech.initialize();
}

Future<void> _listen() async {
  if (!_speechAvailable) {
    await _initSpeech();
  }
  if (!_speechAvailable) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设备不支持语音输入，请用键盘的麦克风')),
    );
    return;
  }
  await _speech.listen(
    onResult: (r) {
      if (r.finalResult) {
        _controller.text = _controller.text + r.recognizedWords;
      }
    },
    localeId: 'zh_CN',
  );
}
```
在按钮区追加：
```dart
const SizedBox(height: 8),
OutlinedButton.icon(
  key: const ValueKey('smart-entry-voice-btn'),
  icon: const Icon(Icons.mic_none_rounded),
  label: const Text('语音输入'),
  onPressed: _listen,
),
```

- [ ] **Step 2: 测试按钮存在**

`smart_entry_input_page_test.dart` 加：
```dart
testWidgets('语音入口存在', (tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: SmartEntryInputPage()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(const ValueKey('smart-entry-voice-btn')), findsOneWidget);
});
```

- [ ] **Step 3: 运行 + 提交**

Run: `flutter test test/smart_entry/smart_entry_input_page_test.dart`
Expected: PASS

```bash
git add lib/features/smart_entry/pages/smart_entry_input_page.dart test/smart_entry/smart_entry_input_page_test.dart
git commit -m "feat(smart-entry): add voice input via speech_to_text"
```

---

## Task 17: BYOK Key 安全存储 SecureKeyStore

**Files:**
- Create: `lib/features/smart_entry/services/secure_key_store.dart`
- Test: 跳过单测（secure storage 依赖原生，仅静态检查）

- [ ] **Step 1: 写实现**

`lib/features/smart_entry/services/secure_key_store.dart`:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// BYOK API Key 存储。Android 用 Keystore，iOS 用 Keychain。spec §8.2。
/// 不进 SQLite / shared_preferences 明文 / 备份导出。
class SecureKeyStore {
  SecureKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kProvider = 'smart_entry.ai.provider';
  static const _kApiKey = 'smart_entry.ai.api_key';
  static const _kModel = 'smart_entry.ai.model';
  static const _kEnabled = 'smart_entry.ai.enabled';
  static const _kAlwaysCloud = 'smart_entry.ai.always_cloud';

  Future<void> save({
    required String? provider,
    required String? apiKey,
    String? model,
    bool enabled = false,
    bool alwaysCloud = false,
  }) async {
    await _storage.write(key: _kProvider, value: provider);
    await _storage.write(key: _kApiKey, value: apiKey);
    await _storage.write(key: _kModel, value: model);
    await _storage.write(key: _kEnabled, value: enabled.toString());
    await _storage.write(key: _kAlwaysCloud, value: alwaysCloud.toString());
  }

  Future<AiConfig> load() async {
    final enabled = await _storage.read(key: _kEnabled);
    final always = await _storage.read(key: _kAlwaysCloud);
    return AiConfig(
      provider: await _storage.read(key: _kProvider),
      apiKey: await _storage.read(key: _kApiKey),
      model: await _storage.read(key: _kModel),
      enabled: enabled == 'true',
      alwaysCloud: always == 'true',
    );
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

class AiConfig {
  const AiConfig({
    this.provider,
    this.apiKey,
    this.model,
    this.enabled = false,
    this.alwaysCloud = false,
  });
  final String? provider;
  final String? apiKey;
  final String? model;
  final bool enabled;
  final bool alwaysCloud;

  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty && provider != null;
}

final secureKeyStoreProvider = Provider<SecureKeyStore>((ref) {
  return SecureKeyStore(const FlutterSecureStorage());
});
```

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/features/smart_entry/services/secure_key_store.dart`
Expected: 无 error

- [ ] **Step 3: 提交**

```bash
git add lib/features/smart_entry/services/secure_key_store.dart
git commit -m "feat(smart-entry): add secure BYOK key store"
```

> 备份排除：确认 `backup_service.dart` 不序列化 secure storage（secure storage 本就不在 SQLite，通常无需改动；执行时 grep 确认无遗漏）。

---

## Task 18: 云端解析 CloudParser（抽象 + 通义千问实现 + 接入管道）

**Files:**
- Create: `lib/features/smart_entry/parser/cloud_parser.dart`
- Modify: `lib/features/smart_entry/parser/smart_entry_parser.dart`（接入 `_maybeCloudEnhance`）
- Modify: `lib/features/smart_entry/providers/smart_entry_providers.dart`（注入 cloudParser）
- Test: `test/smart_entry/cloud_parser_test.dart`（mock http）

- [ ] **Step 1: 写失败测试（用 fake http 客户端）**

`test/smart_entry/cloud_parser_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record_everything/features/smart_entry/parser/cloud_parser.dart';
import 'package:record_everything/features/smart_entry/models/draft_item.dart';

void main() {
  test('解析云端返回的 JSON 为 DraftItem 列表', () async {
    final fakeResponse = '''
{"items":[{"kind":"bill","title":"午餐","amount_cents":2500,"amount_type":"expense","time":"2026-06-20T12:00:00","remind_time":null,"repeat_rule":null,"category_guess":"餐饮","confidence":0.9}]}
''';
    final client = MockClient((req) async => http.Response(fakeResponse, 200));
    final parser = QwenCloudParser(
      apiKey: 'fake',
      model: 'qwen-plus',
      client: client,
    );

    final items = await parser.parse('午餐花了25', source: DraftSource.nl);
    expect(items, hasLength(1));
    expect(items.first.title, '午餐');
    expect(items.first.amountCents, 2500);
    expect(items.first.kind, DraftKind.bill);
  });

  test('非法 JSON 返回空且不抛', () async {
    final client = MockClient((req) async => http.Response('not json', 200));
    final parser = QwenCloudParser(apiKey: 'x', model: 'm', client: client);
    final items = await parser.parse('任意', source: DraftSource.nl);
    expect(items, isEmpty);
  });

  test('HTTP 错误返回空且不抛', () async {
    final client = MockClient((req) async => http.Response('', 500));
    final parser = QwenCloudParser(apiKey: 'x', model: 'm', client: client);
    expect(await parser.parse('任意', source: DraftSource.nl), isEmpty);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/smart_entry/cloud_parser_test.dart`
Expected: FAIL

- [ ] **Step 3: 写实现**

`lib/features/smart_entry/parser/cloud_parser.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/draft_item.dart';

/// 云端大模型解析抽象。spec §5.4 / §8.3。
/// 强制结构化 JSON 输出，只返回 category_guess 文本，分类匹配留给本地。
abstract class CloudParser {
  Future<List<DraftItem>> parse(String text, {required DraftSource source});
}

/// 不调用云端的占位实现（用户未配置或关闭时用）。
class NoopCloudParser implements CloudParser {
  const NoopCloudParser();
  @override
  Future<List<DraftItem>> parse(String text, {required DraftSource source}) async => const [];
}

/// 通义千问实现。可作其他厂商（智谱/DeepSeek/自定义 OpenAI 兼容）的模板。
class QwenCloudParser implements CloudParser {
  QwenCloudParser({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  static const _systemPrompt = '''你是生活记录解析助手。把用户输入解析为结构化的生活事项或账单。
只返回 JSON，格式：{"items":[{"kind":"bill|lifeItem","title":"","amount_cents":0,"amount_type":"expense|income|none","time":"ISO8601","remind_time":"ISO8601|null","repeat_rule":"daily|weekly|monthly|yearly|null","category_guess":"餐饮","confidence":0.9}]}。
金额单位是分。时间用 ISO8601，相对时间要换算成绝对时间。category_guess 只给中文文本。''';

  @override
  Future<List<DraftItem>> parse(String text, {required DraftSource source}) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': text},
              ],
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(timeout);

      if (resp.statusCode != 200) return const [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final content = (body['choices'] as List).first['message']['content'] as String;
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final items = parsed['items'] as List? ?? [];
      return items
          .map((e) => _fromJson(e as Map<String, dynamic>, source))
          .whereType<DraftItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  DraftItem? _fromJson(Map<String, dynamic> j, DraftSource source) {
    try {
      final kindStr = j['kind'] as String? ?? 'bill';
      final kind = kindStr == 'lifeItem' ? DraftKind.lifeItem : DraftKind.bill;
      final amountTypeStr = j['amount_type'] as String? ?? 'expense';
      final amountType = DraftAmountTypeX.fromString(amountTypeStr);
      final timeStr = j['time'] as String?;
      final time = timeStr != null ? DateTime.parse(timeStr) : DateTime.now();
      final remindStr = j['remind_time'] as String?;
      return DraftItem(
        kind: kind,
        title: j['title'] as String? ?? '未命名',
        amountCents: j['amount_cents'] as int?,
        amountType: amountType,
        time: time,
        remindTime: remindStr == null ? null : DateTime.tryParse(remindStr),
        repeatRule: j['repeat_rule'] as String?,
        categoryGuess: j['category_guess'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.7,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/smart_entry/cloud_parser_test.dart`
Expected: PASS（3 用例）

- [ ] **Step 5: 接入管道 `_maybeCloudEnhance`**

修改 `lib/features/smart_entry/parser/smart_entry_parser.dart`：
```dart
import 'cloud_parser.dart';

class SmartEntryParser {
  SmartEntryParser({DateTime? now, CloudParser cloud = const NoopCloudParser()})
    : _engine = LocalRuleEngine(now: now),
      _cloud = cloud;

  SmartEntryParser.forTest({required DateTime now})
    : _engine = LocalRuleEngine(now: now),
      _cloud = const NoopCloudParser();

  final LocalRuleEngine _engine;
  final CloudParser _cloud;

  Future<EntryDraft> parse(
    String input, {
    DraftSource source = DraftSource.nl,
    String? ocrFullText,
  }) async {
    var items = _engine.parseAll(input);
    items = await _maybeCloudEnhance(items, input, source);
    return EntryDraft(items: items, source: source, rawInput: input, ocrFullText: ocrFullText);
  }

  /// 存在低置信项或空结果时，重跑云端；失败降级返回本地结果。spec §5.3/§5.5。
  Future<List<DraftItem>> _maybeCloudEnhance(
    List<DraftItem> items,
    String input,
    DraftSource source,
  ) async {
    final needCloud = items.isEmpty || items.any((i) => i.isLowConfidence);
    if (!needCloud) return items;
    try {
      final cloudItems = await _cloud.parse(input, source: source).timeout(
        const Duration(seconds: 10),
      );
      if (cloudItems.isEmpty) return items;
      return cloudItems; // 云端结果覆盖本地低置信段
    } catch (_) {
      return items; // 降级
    }
  }
}
```

- [ ] **Step 6: 在 provider 注入真实 CloudParser（按配置）**

修改 `smart_entry_providers.dart` 的 `smartEntryParserProvider`：
```dart
final smartEntryParserProvider = Provider<SmartEntryParser>((ref) async {
  final config = await ref.watch(secureKeyStoreProvider).load();
  final cloud = config.enabled && config.isConfigured
      ? QwenCloudParser(apiKey: config.apiKey!, model: config.model ?? 'qwen-plus')
      : const NoopCloudParser();
  return SmartEntryParser(cloud: cloud);
});
```
> 因为 `load()` 是 Future，这个 provider 改为 `FutureProvider`：
```dart
final smartEntryParserProvider = FutureProvider<SmartEntryParser>((ref) async {
  final config = await ref.watch(secureKeyStoreProvider).load();
  final cloud = config.enabled && config.isConfigured
      ? QwenCloudParser(apiKey: config.apiKey!, model: config.model ?? 'qwen-plus')
      : const NoopCloudParser();
  return SmartEntryParser(cloud: cloud);
});
```
调用处 `ref.read(smartEntryParserProvider)` 改为 `ref.read(smartEntryParserProvider.future)`。同步更新 `smart_entry_input_page_test.dart`（单测用内存 db 且未配置云，FutureProvider 解析为 NoopCloudParser，测试仍应通过；若测试因 async 报错，加 `await tester.pumpAndSettle()`）。

- [ ] **Step 7: 运行全部 + 提交**

Run: `flutter test test/smart_entry/`
Expected: 全 PASS（如有 input page 测试因 FutureProvider 超时，按提示补 pumpAndSettle）

Run: `flutter analyze lib/features/smart_entry`
Expected: 无 error

```bash
git add lib/features/smart_entry/parser/cloud_parser.dart lib/features/smart_entry/parser/smart_entry_parser.dart lib/features/smart_entry/providers/smart_entry_providers.dart test/smart_entry/cloud_parser_test.dart test/smart_entry/smart_entry_input_page_test.dart
git commit -m "feat(smart-entry): add cloud parser (qwen) and wire into pipeline with fallback"
```

---

## Task 19: BYOK 设置页 + 设置入口

**Files:**
- Create: `lib/features/smart_entry/pages/ai_assistant_settings_page.dart`
- Modify: `lib/features/settings/pages/settings_page.dart`（加"AI 助手"入口）
- Modify: `lib/core/router/app_router.dart`（加 `/settings/ai-assistant` 路由）

- [ ] **Step 1: 写实现**

`lib/features/smart_entry/pages/ai_assistant_settings_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/smart_entry_providers.dart';
import '../services/secure_key_store.dart';

class AiAssistantSettingsPage extends ConsumerStatefulWidget {
  const AiAssistantSettingsPage({super.key});

  @override
  ConsumerState<AiAssistantSettingsPage> createState() =>
      _AiAssistantSettingsPageState();
}

class _AiAssistantSettingsPageState
    extends ConsumerState<AiAssistantSettingsPage> {
  bool _loading = true;
  bool _enabled = false;
  bool _alwaysCloud = false;
  String _provider = 'qwen';
  String _apiKey = '';
  String _model = 'qwen-plus';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await ref.read(secureKeyStoreProvider).load();
    setState(() {
      _enabled = cfg.enabled;
      _alwaysCloud = cfg.alwaysCloud;
      _provider = cfg.provider ?? 'qwen';
      _apiKey = cfg.apiKey ?? '';
      _model = cfg.model ?? 'qwen-plus';
      _loading = false;
    });
  }

  Future<void> _save() async {
    await ref.read(secureKeyStoreProvider).save(
      provider: _provider,
      apiKey: _apiKey,
      model: _model,
      enabled: _enabled,
      alwaysCloud: _alwaysCloud,
    );
    // 刷新 parser provider 使新配置生效
    ref.invalidate(smartEntryParserProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用智能输入'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          ListTile(
            title: const Text('提供商'),
            trailing: DropdownButton<String>(
              value: _provider,
              items: const [
                DropdownMenuItem(value: 'qwen', child: Text('通义千问')),
                DropdownMenuItem(value: 'zhipu', child: Text('智谱')),
                DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek')),
                DropdownMenuItem(value: 'custom', child: Text('自定义')),
              ],
              onChanged: (v) => setState(() => _provider = v ?? 'qwen'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()),
              obscureText: true,
              onChanged: (v) => _apiKey = v,
              controller: TextEditingController(text: _apiKey),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(labelText: '模型', border: OutlineInputBorder()),
              onChanged: (v) => _model = v,
              controller: TextEditingController(text: _model),
            ),
          ),
          SwitchListTile(
            title: const Text('始终使用云端'),
            subtitle: const Text('关闭时仅本地解析不出时才走云'),
            value: _alwaysCloud,
            onChanged: (v) => setState(() => _alwaysCloud = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 设置页加入口 + 路由**

`settings_page.dart` 在合适位置（其他 ListTile 之间）加：
```dart
ListTile(
  leading: const Icon(Icons.auto_awesome_outlined),
  title: const Text('AI 助手'),
  subtitle: const Text('智能输入 / BYOK 配置'),
  onTap: () => context.push('/settings/ai-assistant'),
),
```

`app_router.dart` 在 `/settings` 的 routes 里加：
```dart
GoRoute(
  path: 'ai-assistant',
  builder: (context, state) => const AiAssistantSettingsPage(),
),
```
顶部 import：
```dart
import '../../features/smart_entry/pages/ai_assistant_settings_page.dart';
```

- [ ] **Step 3: 静态检查 + 提交**

Run: `flutter analyze lib/features/smart_entry/pages/ai_assistant_settings_page.dart lib/features/settings/pages/settings_page.dart lib/core/router/app_router.dart`
Expected: 无 error

```bash
git add lib/features/smart_entry/pages/ai_assistant_settings_page.dart lib/features/settings/pages/settings_page.dart lib/core/router/app_router.dart
git commit -m "feat(smart-entry): add BYOK AI assistant settings page"
```

---

## Task 20: 端到端冒烟测试 + 文档收尾

**Files:**
- Create: `test/smart_entry/smart_entry_e2e_test.dart`
- Modify: `README.md`（加智能输入说明，标注 iOS 见 spec §14）

- [ ] **Step 1: 写端到端测试**

`test/smart_entry/smart_entry_e2e_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:record_everything/data/database/app_database.dart';
import 'package:record_everything/data/database/database_provider.dart';
import 'package:record_everything/data/repositories/bill_record_repository.dart';
import 'package:record_everything/features/smart_entry/pages/smart_entry_input_page.dart';

void main() {
  testWidgets('输入 → 解析 → 确认 → 保存 → 账单入库', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SmartEntryInputPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('smart-entry-input-field')),
      '午餐花了25',
    );
    await tester.tap(find.byKey(const ValueKey('smart-entry-parse-btn')));
    await tester.pumpAndSettle();

    // 确认页
    expect(find.text('解析结果'), findsOneWidget);
    await tester.tap(find.text('保存全部 1 条'));
    await tester.pumpAndSettle();

    // 验证入库（repo 只有 watchAll，取 stream 首帧）
    final bills = await BillRecordRepository(db).watchAll().first;
    expect(bills, hasLength(1));
    expect(bills.first.amount, 2500);
    expect(bills.first.title, contains('午餐'));
  });
}
```

> 说明：`BillRecordRepository` 无 `getAll()`，只有 `watchAll()` stream；这里取 `.first` 验证。若测试因 stream 时序不稳，改用 `await tester.pumpAndSettle()` 后再读，或注入 DAO 直接 `get()`。

- [ ] **Step 2: 运行全部测试**

Run: `flutter test test/smart_entry/`
Expected: 全 PASS

Run: `flutter test`
Expected: 全 PASS（含既有测试，确认无回归）

Run: `flutter analyze`
Expected: 无 error

- [ ] **Step 3: README 收尾**

在 `README.md` 适当章节加一段：
```markdown
## 智能输入（Smart Entry）

首页右上角"+ → 智能输入"，支持：
- 自然语言一句话创建事项/账单（"明天3点开会，午餐花了25"）
- 拍照/选图识图记账（端侧 OCR）
- 系统分享文字直接解析
- 语音输入

解析在本地优先完成，复杂输入可配置云端大模型兜底（设置 → AI 助手，BYOK 自带 API Key）。
数据不上传服务器，云端仅在开启且配置后按需调用。

> 当前仅 Android；iOS 支持见 `docs/superpowers/specs/2026-06-19-smart-entry-design.md` §14。
```

- [ ] **Step 4: 提交**

```bash
git add test/smart_entry/smart_entry_e2e_test.dart README.md
git commit -m "test(smart-entry): add e2e smoke test and document feature"
```

---

## 手动测试清单（依赖真机/外部环境）

执行完所有 Task 后，在真机上验证以下场景（无法自动化）：

- [ ] 首页 → + → 智能输入 → 输入"明天3点开会，午餐花了25" → 确认页两条 → 全部保存 → 事项列表 + 账单列表各多一条
- [ ] 事项保存后若配置了提醒时间，系统通知按时触发（验证 `ReminderScheduler` 链路）
- [ ] 智能输入页 → 📷 → 选一张超市/便利店小票 → 确认页有金额 → 保存 → 账单入库
- [ ] 智能输入页 → 📷 → 选一张微信/支付宝账单截图 → 确认页有金额
- [ ] 在浏览器复制一段文字 → 系统分享菜单 → 选"生活事项" → 跳确认页（冷启动 + 热启动各一次）
- [ ] 智能输入页 → 🎤 → 说"下午买咖啡花了二十" → 文本回填 → 解析 → 确认页
- [ ] 设置 → AI 助手 → 填通义千问 Key + 启用 → 输入复杂语句（"下周三之前把护照续了顺便提醒我带上照片"）→ 确认页解析结果优于纯本地
- [ ] 关闭网络 + 未配置云 → 上述简单输入仍正常（验证离线降级）
- [ ] 关闭网络 + 已配置云但超时 → 确认页顶部出现降级提示，本地结果仍可用

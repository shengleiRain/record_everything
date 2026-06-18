# 智能录入（Smart Entry）设计文档

- **状态**：已确认（设计阶段）
- **日期**：2026-06-19
- **范围**：阶段一 —— AI 智能录入 + 识图记账
- **目标平台**：仅 Android

## 1. 背景与目标

record_everything 是一款统一的生活管理 App，已具备完整的"生活事项 / 账单 / 项目"CRUD、模板、统计、提醒、备份等能力。当前的录入入口是分类型的表单页（建事项 / 建账单），用户需要先判断类型、再逐项填写字段，录入成本较高。

本设计旨在引入一条全新的"智能录入通道"，降低录入摩擦：

- **快速输入**：自然语言一句话创建事项/账单
- **识图记账**：拍小票或选账单截图，OCR 自动提取金额/日期/商家
- **系统分享接入**：从微信/短信/浏览器分享文字进来，自动解析
- **语音输入**：语音转文字再解析

这是"提升便捷性"三阶段路线的**第一阶段**（高频痛点）。后续两个阶段（桌面与锁屏触达、智能洞察与自动化）将单独立项。

## 2. 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 目标平台 | 仅 Android | 当前主要在 Android 上运行 |
| AI 实现 | 本地 + 云端混合，端侧优先 | 95% 日常使用离线可用、零成本、隐私好；复杂语义按需走云 |
| 云端接入 | BYOK（用户自带 Key） | 零运营成本、零后端、隐私可控、避免内置密钥被逆向抽取 |
| 草稿存储 | 纯内存，不落库 | 不污染 schema、无需迁移；退出即作废，与主流记账 App 一致 |
| 解析策略 | 本地规则引擎优先 + 置信度切换 + 云端兜底 | 高频规范输入本地搞定，复杂输入云端补 |

## 3. 整体架构：多入口、单管道

四个入口输入形态不同（文本/图片/分享文本/语音），但最终都汇入同一条"解析 → 草稿 → 确认 → 落库"管道。

```
┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐
│ 快速输入 FAB │  │ 识图记账相机  │  │ 系统分享接收器 │  │ 语音输入     │
│  (文本框)    │  │  (拍照/选图)  │  │ (share intent)│  │ (系统键盘)   │
└──────┬──────┘  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘
       │ 文本           │ 图片+OCR       │ 文本              │ 文本
       │                │→转成文本       │                  │
       └────────────────┴────────┬───────┴──────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │  SmartEntryParser        │  ← 核心抽象
                    │  1. 本地规则引擎先解析     │  ← 95% 在此完成
                    │  2. 本地解不出→云模型兜底   │  ← BYOK, 可开关
                    └────────────┬─────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │  EntryDraft(草稿模型)    │
                    └────────────┬─────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │  草稿确认页（必经环节）     │
                    └────────────┬─────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │  现有 Repository 落库     │
                    │  (lifeItemRepo/billRepo) │
                    └─────────────────────────┘
```

**核心原则**：
- `SmartEntryParser` 是核心抽象，所有入口喂给它纯文本（图片先 OCR、语音先转文字）。
- AI 解析结果**永不直接落库**，必须经草稿确认页。
- 复用现有 `LifeItemRepository.create()` / `BillRecordRepository.create()`，不改表、不改状态机。

## 4. 数据模型

### 4.1 DraftItem / EntryDraft

草稿是对"未确认的解析结果"的轻量描述，1:1 映射到现有 Repository 入参，不引入新表。

```dart
enum DraftKind { lifeItem, bill }
enum DraftSource { nl, ocr, share, voice }

class DraftItem {
  final DraftKind kind;
  final String title;
  final int? amountCents;          // 与现有"整数分"存储对齐
  final AmountType amountType;     // none | expense | income
  final DateTime time;             // 事项=dueTime，账单=billTime
  final DateTime? remindTime;      // 仅事项
  final String? repeatRule;        // 仅事项，复用现有 RepeatRule 字符串格式
  final int? categoryId;           // AI/OCR 推断，用户可改
  final String? categoryGuess;     // 推断失败时的文本（如"餐饮"）供用户选
  final double confidence;         // 0.0~1.0
  final List<String> parseNotes;   // 解析说明
  final DraftSource source;
}

class EntryDraft {
  final List<DraftItem> items;     // 一句话可拆出多条
  final DraftSource source;
  final String rawInput;
  final String? ocrFullText;       // 仅 OCR 来源保留全文本
}
```

### 4.2 设计要点

1. **草稿不落库，纯内存**。生命周期是"解析完到确认入库之间"，退出即丢。
2. **`categoryId` 可空 + `categoryGuess` 文本兜底**。OCR/AI 常只能推断文字而匹配不到 ID，确认页让用户选分类。
3. **`confidence` 驱动 UI**：高置信直接展示为可入库卡片，低置信（< 0.6）打"⚠️ 请核对"。也决定是否走云端兜底。
4. **一句话可拆多条**：`EntryDraft.items` 是列表，确认页作为独立卡片分别编辑/删除。
5. **不复用现有 `LifeItem`/`BillRecord` 类型**：故意保持"未落库草稿"和"已落库实体"的清晰边界，避免 Drift 生成类的 id/createdAt 等落库字段干扰。

## 5. 解析管道 SmartEntryParser

### 5.1 管道结构

```
输入文本
   ▼
1. Preprocessor（本地）：去标点/全半角统一，中英数字→阿拉伯数字（"二十五"→25）
   ▼
2. Splitter（本地）：按 ，, ；; 。. 换行 拆分，每段独立解析
   ▼
3. LocalRuleEngine（本地）：
   · 金额提取（正则 + 单位推断）
   · 日期/时间解析（相对/绝对）
   · 分类关键词匹配（复用现有分类）
   · 事项 vs 账单判定
   输出：List<DraftItem> + 置信度
   ▼
   ┌──全部高置信──→ 5. 装配 EntryDraft
   └──有低置信项──→ 4. CloudParser（BYOK, 可开关，仅重跑低置信段）
                       ▼
                    5. 合并 + 装配 EntryDraft
```

### 5.2 本地规则引擎的 4 类抽取

| 抽取项 | 示例 | 方法 | 典型置信度 |
|--------|------|------|-----------|
| 金额 | "花了25"、"￥120.5"、"两万三"、"1k" | 正则 + 中文数字/单位词表 + MoneyFormatter 反向解析 | 高（0.9+） |
| 时间 | "明天"、"下周五3点"、"后天下午"、"每月15号" | 相对时间枚举 + 绝对日期正则 + RepeatRule 解析 | 中（0.7~0.9） |
| 分类 | "午餐"、"打车"、"工资"、"续费" | 现有 Categories 表 name/icon + 关键词匹配 | 中（0.6~0.8） |
| 事项/账单判定 | "开会"、"记得"、"提醒" vs "花了"、"买了"、"收入" | 动词词表 + 有无金额 + 有无重复规则 | 中高（0.75+） |

**判定优先级**：
1. 含消费/收入动词 + 有金额 → **账单**
2. 含任务动词，或含重复规则 → **事项**
3. 仅金额无明确动词 → 默认**支出账单**（最常见）
4. 都不含 → 走云端兜底

### 5.3 何时触发云端兜底

满足任一条件，对**低置信的那几段**（不是全部）走云端：
- 任一 `DraftItem.confidence < 0.6`
- 某段解析出 0 个 `DraftItem`
- 用户设置开了"总是使用云端"

云端只重跑低置信段，返回的结构化 JSON 映射成同样的 `DraftItem` 覆盖本地结果。省 token、省时间。

### 5.4 云端协议契约

强制要求结构化 JSON 输出（`response_format: json_schema` 或 function calling），约定 schema：

```json
{
  "items": [
    {
      "kind": "bill | lifeItem",
      "title": "午餐",
      "amount_cents": 2500,
      "amount_type": "expense | income | none",
      "time": "2026-06-20T12:00:00",
      "remind_time": null,
      "repeat_rule": null,
      "category_guess": "餐饮",
      "confidence": 0.85
    }
  ]
}
```

**云端只返回 `category_guess` 文本，不返回 `categoryId`**——分类匹配必须用本地的分类表做（云端不知道用户建了哪些自定义分类）。这把"云端理解语义"和"本地匹配分类"两个职责彻底切开。

### 5.5 失败与降级

| 情况 | 行为 |
|------|------|
| 云端未配置或关闭 | 用本地结果，低置信项照常进确认页 |
| 云端调用失败/超时（10s） | 降级本地结果 + 顶部提示"AI 增强不可用" |
| 云端返回非法 JSON / schema 不符 | 丢弃云端结果，降级本地结果 |
| 本地和云端都解析出 0 条 | 进入确认页空态，引导手动填写 |

**安全原则**：云端永远只是"锦上添花"，任何云端故障都不能阻断主流程——本地结果始终可用。

## 6. 四个入口

### 6.1 快速输入 FAB（主入口）

- **位置**：复用首页右下角 FAB → 触发 `quick_create_sheet`，在面板**顶部**新增"智能输入"横幅卡片（视觉权重高于下方 6 格）。
- **交互**：点横幅 → push `/smart-entry/input` → 自动聚焦输入框，占位提示 `试试 "明天3点开会 午餐花了25"`。支持多行，右下角"解析"按钮 + 📷按钮（接识图）。点击解析 → 调 SmartEntryParser → 跳草稿确认页。
- **理由**：首页已有 5 Tab + 一个 FAB，不另加 FAB，保持"一个入口承载所有快速记录"。

### 6.2 识图记账（主入口）

- **进入**：快速输入页的 📬 + 账单列表页右下角"扫描"入口。
- **交互**：📷 → `image_picker` 选图/拍照 → `google_mlkit_text_recognition`（端侧、免费、离线）提取文本 → 喂给 SmartEntryParser（source=ocr）→ 草稿确认页**额外展示原图缩略图 + OCR 全文折叠面板**。
- **OCR 特化规则**（LocalRuleEngine 里为 ocr 来源加）：
  - 金额优先抓"合计/实付/Total"后的数字，带 ¥/￥/RMB 单位
  - 日期匹配 `2026-06-19`/`2026/6/19`/`6月19日`
  - 商家名取顶部第一行非数字文本 → title 候选
  - 微信/支付宝账单截图有固定格式 → 专门格式化解析器
- **置信度**：OCR 来源金额置信普遍偏低，**默认更倾向走云端兜底**（若开启）；不开云也能处理标准格式小票。

### 6.3 系统分享接入

- **场景**：从其他 App 分享文本（"明天下午3点开会，记得带资料"）→ 选"生活事项" → 自动解析。
- **实现**：`receive_sharing_intent` 插件。
- **Manifest 改动**：activity 新增 SEND intent-filter（mimeType text/plain）。
- **交互**：分享进来 → 拿到文本 → 直接跳草稿确认页（跳过输入框），source=share，顶部显示"来自分享"标识 + 原文预览。
- **冷热启动**：插件区分冷启动（initState 读初始 sharing）和热启动（StreamSubscription 监听 onNewIntent），两者都要处理——这是此类功能最易出 bug 的点。

### 6.4 语音输入（低成本，复用）

- **不做独立 ASR**，复用 Android 系统语音输入键盘（Gboard/搜狗/百度都自带）。
- **交互**：输入框聚焦弹键盘时引导用键盘麦克风；输入框"解析"按钮旁加 🎤，点击：
  - 系统有 `RecognizerIntent` → 用 `speech_to_text` 调起，结果回填输入框
  - 没有 → toast 提示用键盘语音
- **理由**：系统语音键盘已覆盖 95% 中文语音输入，体验最好、零集成成本；`speech_to_text` 仅兜底。

## 7. 草稿确认页

所有入口解析后的唯一汇聚点。原则：**AI 永不直接落库，用户必经此页；但让"确认"尽可能快。**

### 7.1 页面结构

```
┌─────────────────────────────────────┐
│  ← 解析结果              [全部保存] │  AppBar
├─────────────────────────────────────┤
│  📌 来自：语音/识图/分享              │  来源标识条
│  原文："明天3点开会 午餐花了25"       │  可折叠
├─────────────────────────────────────┤
│  DraftItem 卡片 ×N                   │
│   · 低置信：橙色竖条 + ⚠️ + parseNotes│
│   · 高置信：正常卡片                  │
│   · 每卡可编辑 title/时间/提醒/分类/金额│
│   · 每卡可删除（右滑或按钮）          │
├─────────────────────────────────────┤
│  ＋ 手动添加一条                     │
├─────────────────────────────────────┤
│            [ 保存全部 N 条 ]         │  底部固定按钮
└─────────────────────────────────────┘
```

### 7.2 卡片能力

- title/时间/提醒/分类/金额：点按 inline 编辑或弹选择器（复用现有 `date_field`、分类下拉）
- 删除：移除该条，不影响其他
- 低置信高亮：`confidence < 0.6` 加橙色竖条 + ⚠️ + parseNotes
- 分类匹配失败：显示 `categoryGuess` 文本 + 下拉选实际分类

### 7.3 保存行为

- 遍历 items 按 kind 调 `lifeItemRepository.create()` / `billRecordRepository.create()`
- 部分失败不阻断：失败条标红保留，成功条标 ✓
- 全部成功：Toast "已保存 N 条" + 返回上一页
- 事项保存后自动调度提醒（复用现有 `ReminderScheduler`）

### 7.4 空态

解析出 0 条 → "没识别到可记录的内容" + 手动新建按钮，**绝不卡死空白页**。

## 8. BYOK 设置与云端接入

### 8.1 设置页新增"AI 助手"分区

```
AI 助手
├─ ☑ 启用智能输入
├─ 提供商：    [通义千问 ▼]   （通义千问/智谱/DeepSeek/自定义）
├─ API Key：   [••••••••••••]  （密码框，secure storage）
├─ 模型：      [qwen-plus ▼]   （按提供商给默认值，可改）
├─ ☐ 始终使用云端（关闭=仅本地解不出时才走云）
└─ 🧪 测试连接
```

### 8.2 Key 存储

- 用 `flutter_secure_storage`（Android Keystore 加密），不进 SQLite、不进备份、不进 shared_preferences 明文
- 备份导出时**显式排除 Key**

### 8.3 云端调用层抽象

```dart
abstract class CloudParser {
  Future<List<DraftItem>> parse(String text, {required String source});
}
class QwenCloudParser implements CloudParser { ... }
class ZhipuCloudParser implements CloudParser { ... }
class DeepSeekCloudParser implements CloudParser { ... }
class CustomOpenAiCompatibleParser implements CloudParser { ... }
```

统一接口、各厂商独立实现，统一约定第 5.4 节的 JSON schema。

## 9. 新增依赖

| 包 | 用途 | 必要性 |
|----|------|--------|
| `google_mlkit_text_recognition` | 端侧 OCR（识图记账） | 必需 |
| `image_picker` | 拍照/选图 | 必需 |
| `receive_sharing_intent` | 系统分享接收 | 必需 |
| `speech_to_text` | 语音输入兜底 | 必需 |
| `flutter_secure_storage` | BYOK Key 存储 | 必需 |
| `http` | 云端 API 调用 | 必需 |

## 10. 错误处理与降级矩阵

| 故障点 | 影响 | 降级策略 |
|--------|------|---------|
| OCR 无文字（白图/模糊） | 识图记账无文本 | 确认页空态 + 提示重拍 |
| 本地规则 0 命中 | 单段无草稿 | 该段走云端兜底 / 空态引导手动填 |
| 云端未配置 | 无 AI 增强 | 用本地结果，低置信项照常进确认页 |
| 云端超时（10s）/失败 | 无 AI 增强 | 降级本地结果 + 顶部提示 |
| 云端返回非法 JSON | 无 AI 增强 | 丢弃云端结果 + 降级本地 |
| 分享 intent 解析失败 | 分享进不来 | Toast 报错，不崩 |
| `RecognizerIntent` 不存在 | 语音入口不可用 | 提示用键盘语音 |

核心原则：任何云端/外部依赖的故障都不能阻断本地主流程。

## 11. 测试策略

| 层次 | 覆盖 |
|------|------|
| 单元测试（重点） | LocalRuleEngine 的金额/时间/分类抽取规则——每种输入模式一个用例；Preprocessor 全半角/数字转换；Splitter 分句；EntryDraft 装配；各 CloudParser 的 JSON→DraftItem 映射（mock http） |
| 组件测试 | 草稿确认页：卡片渲染、低置信高亮、删除、编辑、全部保存、部分失败标记；快速输入页：输入→解析跳转 |
| 集成测试 | 端到端：输入"午餐花了25" → 确认页显示账单 → 保存 → 账单列表可见 |
| 手动测试 | 识图记账（真实小票）、系统分享（从微信分享进来）、语音输入——依赖真机和外部环境 |

LocalRuleEngine 是测试重中之重，因为它是 95% 流量的承载者，且规则会持续迭代。

## 12. 文件结构

```
lib/
  features/
    smart_entry/                         ← 新增功能模块
      models/
        draft_item.dart                  ← DraftItem / EntryDraft / 枚举
      parser/
        smart_entry_parser.dart          ← 管道编排（公开入口）
        preprocessor.dart                ← 文本预处理
        splitter.dart                    ← 分句
        local_rule_engine.dart           ← 本地规则（金额/时间/分类/判定）
        cloud_parser.dart                ← CloudParser 抽象 + 各厂商实现
      providers/
        smart_entry_providers.dart       ← Riverpod Provider 编排
      pages/
        smart_entry_input_page.dart      ← 快速输入页
        smart_entry_confirm_page.dart    ← 草稿确认页
      widgets/
        draft_item_card.dart             ← 草稿卡片
        ocr_preview_panel.dart           ← OCR 原文/图片预览
        cloud_unavailable_banner.dart    ← 云端降级提示条
  core/
    constants/
      smart_entry_keywords.dart          ← 动词词表/分类关键词/单位词表
```

## 13. 实施切片

按依赖顺序，每片独立交付、独立测试：

1. **切片 1：数据模型 + 本地规则引擎**（draft_item.dart + preprocessor/splitter/local_rule_engine + 关键词表 + 单测）——地基，先跑通"文本→草稿"，UI 还没有也能用单测验
2. **切片 2：草稿确认页 + 接入现有 Repository**（smart_entry_confirm_page + draft_item_card + 落库逻辑）——让切片 1 的产出能真正存进数据库
3. **切片 3：快速输入 FAB 入口**（smart_entry_input_page + 接入 quick_create_sheet + 路由）——第一个完整可用的入口，MVP 完成
4. **切片 4：识图记账**（OCR 集成 + LocalRuleEngine 的 OCR 特化规则 + ocr_preview_panel）
5. **切片 5：系统分享接入**（receive_sharing_intent + Manifest intent-filter + 冷热启动处理）
6. **切片 6：语音输入**（speech_to_text 集成）
7. **切片 7：BYOK 设置 + 云端兜底**（设置页 + flutter_secure_storage + 各厂商 CloudParser + 管道接入云端分支）

切片 1-3 是 MVP（纯本地、零依赖、可立即提升录入体验）；4-7 是增量增强。每个切片都能独立交付价值。

## 14. 后续阶段（路线图，本次不实现）

- **阶段二：桌面与锁屏触达** —— 桌面 App Widget（今日待办/一键记账/本月预算环形）+ Android 16 Live Updates 锁屏实时倒计时 + App Shortcuts + Quick Settings Tile。单独立项。
- **阶段三：智能洞察与自动化** —— 消费趋势/异常预警、自动分类建议、（可选）短信自动记账。本地统计算法为主。单独立项。

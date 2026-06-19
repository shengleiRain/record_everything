# 阶段三：智能洞察与自动化 设计文档

- **状态**：已确认
- **日期**：2026-06-19
- **范围**：消费趋势分析 + 自动分类建议
- **目标平台**：Android（纯 Dart 层，跨平台）

## 1. 背景与目标

阶段一解决了"录入麻烦"，阶段二解决了"忘记看"。阶段三解决"看不懂"——帮用户理解自己的消费模式，并减少重复操作。

本次实现 **消费趋势分析**（周/日/分类趋势图表）和 **自动分类建议**（根据历史账单标题推荐分类）。异常预警和短信自动记账不在本次范围内。

## 2. 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 图表库 | `fl_chart`（已在 pubspec 中声明） | 已有依赖，不增加新依赖，功能强大 |
| 趋势页面位置 | 现有统计页面新增分区 | 不新建页面，复用现有月度导航和数据加载 |
| 自动分类算法 | 标题模糊匹配 + 使用频率排序 | 简单有效，无需 ML 模型，纯本地 |
| 推荐展示方式 | 分类选择器旁 chip | 非侵入式，用户可忽略也可一键采纳 |

## 3. 消费趋势分析

### 3.1 新增 DAO 方法

**`BillRecordDao.watchDailySumsForMonth(DateTime month, String amountType)`**
→ `Stream<List<DailySumRow>>`，按日 GROUP BY，返回 `[{date, total}]`

**`BillRecordDao.watchCategoryMonthlySums(DateTime start, DateTime end, String amountType)`**
→ `Stream<List<CategoryMonthlySumRow>>`，按月+分类 GROUP BY，返回 `[{year, month, categoryId, categoryName, total}]`

### 3.2 新增 Provider

| Provider | 类型 | 数据 |
|----------|------|------|
| `statsWeeklyTrendProvider` | `StreamProvider<List<WeeklySumRow>>` | 最近 8 周每周支出总额 |
| `statsDailyTrendProvider` | `StreamProvider<List<DailySumRow>>` | 当月每日支出总额 |
| `statsCategoryTrendProvider` | `StreamProvider<List<CategoryMonthlySumRow>>` | 最近 6 个月 Top 5 分类月度支出 |

### 3.3 UI 组件

在 `statistics_page.dart` 的 `_MonthlyTrendChart` 之后新增：

**周消费趋势折线图**（`fl_chart` LineChart）：
- X 轴：最近 8 周（"W1", "W2", ...）
- Y 轴：支出金额（元）
- 折线 + 面积填充
- 最高点标注金额

**日消费柱状图**（`fl_chart` BarChart）：
- X 轴：当月日期（1~31）
- Y 轴：当日支出
- 超过当月日均 1.5 倍的柱子标红

**Top 5 分类趋势**（`fl_chart` BarChart 堆叠）：
- X 轴：最近 6 个月
- Y 轴：支出金额
- 每个分类一种颜色，图例在下方

### 3.4 文件结构

```
lib/features/statistics/
  providers/statistics_providers.dart   ← 新增 3 个 provider
  widgets/
    weekly_trend_chart.dart             ← 周趋势折线图
    daily_trend_chart.dart              ← 日消费柱状图
    category_trend_chart.dart           ← 分类趋势堆叠图
```

修改文件：
```
lib/data/database/daos/bill_record_dao.dart   ← 新增 2 个 DAO 方法
lib/features/statistics/pages/statistics_page.dart ← 插入图表组件
```

## 4. 自动分类建议

### 4.1 新增 DAO 方法

**`BillRecordDao.suggestCategoryByTitle(String keyword, String amountType)`**
→ `Future<int?>`，查询标题包含 keyword 的账单，GROUP BY category_id，返回使用次数最多的 category_id。

实现逻辑：
```sql
SELECT category_id, COUNT(*) as cnt
FROM bill_records
WHERE title LIKE '%keyword%'
  AND amount_type = ?
  AND deleted_at IS NULL
  AND category_id IS NOT NULL
GROUP BY category_id
ORDER BY cnt DESC
LIMIT 1
```

边界：keyword 长度 < 2 → 返回 null（避免误匹配）。

### 4.2 新增 Provider

**`categorySuggestionProvider(String title, String amountType)`**
→ `FutureProvider<int?>`，调用 DAO 查询推荐分类 id。

### 4.3 UI 集成

**账单编辑页**（`bill_edit_page.dart`）：
- 标题输入框 `onChanged` 时 debounce 500ms，触发 `categorySuggestionProvider`
- 分类选择器旁显示"💡 推荐：餐饮"chip（仅当有推荐且用户未手动选择时）
- 点击 chip → 自动选中推荐分类

**智能录入确认页**（`smart_entry_confirm_page.dart`）：
- 草稿卡片的分类字段已有 `categoryGuess` 文本
- 新增：如果 `categoryId` 为空，查询 `categorySuggestionProvider(title, amountType)` 作为补充推荐
- 推荐结果显示在分类字段旁

### 4.4 文件结构

```
lib/features/smart_entry/
  providers/smart_entry_providers.dart   ← 新增 categorySuggestionProvider
```

修改文件：
```
lib/data/database/daos/bill_record_dao.dart   ← 新增 suggestCategoryByTitle
lib/features/bill/pages/bill_edit_page.dart    ← 推荐 chip
lib/features/smart_entry/widgets/draft_item_card.dart ← 推荐 chip
```

## 5. 测试策略

| 层次 | 覆盖 |
|------|------|
| 单元测试 | DAO 方法：watchDailySumsForMonth、watchCategoryMonthlySums、suggestCategoryByTitle（用内存数据库） |
| 单元测试 | Provider：验证 weeklyTrend/dailyTrend/categoryTrend 正确聚合数据 |
| 组件测试 | 图表组件：验证渲染不崩溃、数据点数量正确 |
| 组件测试 | 自动分类 chip：有推荐时显示、点击选中、无推荐时隐藏 |

## 6. 实施切片

1. **切片 1：DAO 方法**（watchDailySumsForMonth + watchCategoryMonthlySums + suggestCategoryByTitle + 单测）
2. **切片 2：Provider**（statsWeeklyTrendProvider + statsDailyTrendProvider + statsCategoryTrendProvider + categorySuggestionProvider + 单测）
3. **切片 3：趋势图表 UI**（weekly_trend_chart + daily_trend_chart + category_trend_chart + 接入统计页）
4. **切片 4：自动分类 UI**（bill_edit_page chip + draft_item_card chip）

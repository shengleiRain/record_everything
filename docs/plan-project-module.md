# 通用项目模块 + 轻量摄影接单模板 + 统计增强规划

> 创建日期：2026-06-10
> 修订日期：2026-06-10
> 状态：已实施完成

## 0. 假设、约束与成功标准

### 假设

- 项目是容器，不替代现有事项和账单。
- 事项、账单可以归属于某个项目；无项目事项/账单保持原行为。
- 摄影接单是首个高频场景，但只做轻量模板，不做完整 CRM、合同、发票或客户管理系统。
- 收款计划优先复用事项能力：可提醒、可逾期、可完成；实际收款仍由账单记录。
- 项目类型通过现有分类系统承载，用户可自行扩展。

### 约束

- 迁移必须向后兼容，旧数据不能被强制归入任何项目。
- 不引入重型动态字段系统；MVP 只保留少量通用项目字段。
- 不把摄影专用概念写死到项目主表；摄影只存在于模板、默认文案和可选分类建议里。
- 统计查询优先通过 SQL 聚合完成，避免在 Dart 层全量加载账单后再计算。

### 可衡量成功标准

- v2 -> v3 迁移后，旧事项和旧账单数量不变，新增 `projectId` 均为 `null`。
- 可以创建一个“摄影接单”项目，记录客户/拍摄对象、拍摄日期、拍摄类型、约定总额。
- 可以为同一个项目生成定金、尾款等应收事项，并在实际收款时创建关联账单。
- 项目详情可展示：应收、已收、待收、项目支出、净额、事项、账单、时间线。
- 无项目事项/账单在首页、事项页、账单页、统计页中行为不变。
- 统计页能展示近 6 个月趋势、分类占比、环比对比，并能体现项目收入/进行中项目数。
- 备份、恢复、回收站覆盖项目数据，不丢失项目与事项/账单的关系。

---

## 1. 背景与核心设计

用户有摄影接单的高频场景：每个订单需要记录拍摄日期、拍摄类型、客户/拍摄对象、定金尾款、时间脉络，以及摄影相关投资支出。同时模块应通用于活动策划、旅行规划、客户项目等结构化场景。

核心设计：

```
Project（项目容器）
├── LifeItems（项目内事项/里程碑/应收提醒）
├── BillRecords（项目内实际收入/支出）
└── ProjectEvents（项目内手动事件/沟通/状态变更）
```

设计原则：

- 项目负责组织上下文。
- 事项负责未来动作、提醒、里程碑和应收计划。
- 账单负责真实资金流水。
- 时间线是合并视图，不是所有事件的重复存储。
- 分类负责项目类型、事项类型、收支类型，不用项目表承载所有行业字段。

---

## 2. 参考产品与设计理念

| 产品 | 可借鉴点 | 对本项目的启发 |
|------|----------|----------------|
| Todoist | Project 是相关任务的空间，可归档、可模板化 | 项目作为容器，常见项目用模板快速生成事项 |
| Things 3 | 同一批待办可按“上下文”和“时间”两种视角查看 | 项目详情看上下文，首页日历看时间 |
| Notion | Relation/Rollup 连接数据库并汇总相关数据 | `projectId` 关联事项/账单，项目页做汇总 |
| Asana | 自定义字段、状态、时间线用于项目推进 | 保留状态和关键日期，但不做复杂字段系统 |
| YNAB/随手记类记账 | 交易保留分类，同时可按时间、分类、账户筛选 | 项目维度不要替代收支分类，应形成第二分析维度 |

落地理念：

- 对摄影用户，减少重复录入：创建项目后自动生成常见事项和应收提醒。
- 对通用用户，保持轻量：不用模板也能创建一个普通项目。
- 对统计，保持双维度：分类回答“钱花在哪/收入来自哪”，项目回答“这件事整体值不值/进展如何”。

---

## 3. 摄影接单轻量模板

### 3.1 模板目标

模板只解决高频录入，不扩展为行业系统。

创建“摄影接单”项目时，用户可选择套用轻量模板，表单字段：

- 项目标题：如“张先生婚礼拍摄”
- 拍摄类型：订婚/婚礼/写真/商业/其他，可手输
- 客户/拍摄对象
- 拍摄日期
- 约定总额
- 定金金额与应收/实收日期（可选）
- 尾款金额与应收日期（可选）
- 备注

### 3.2 模板生成内容

假设项目为“张先生婚礼拍摄”，拍摄日期为 7/15，总价 5000，定金 2000，尾款 3000。

创建项目：

- `Project.title = 张先生婚礼拍摄`
- `Project.categoryId = 摄影接单`
- `Project.participant = 张先生`
- `Project.startDate = 7/15`
- `Project.totalAmount = 500000`
- `Project.projectStatus = active/planned`
- `Project.note` 保存拍摄类型、补充说明等轻量文本

自动生成事项：

- “收定金”：
  - `LifeItem.itemType = payment_due`
  - `amountType = income`
  - `amount = 200000`
  - `dueTime = 定金应收日期`
  - `projectId = 当前项目`
- “拍摄日提醒”：
  - `itemType = milestone`
  - `dueTime = 拍摄日期`
- “选片/确认交付内容”：
  - `itemType = todo`
  - `dueTime = 拍摄日期后若干天`
- “修图交付”：
  - `itemType = delivery`
  - `dueTime = 拍摄日期后若干天`
- “收尾款”：
  - `itemType = payment_due`
  - `amountType = income`
  - `amount = 300000`
  - `dueTime = 尾款应收日期`

实际收款：

- 创建 `BillRecord`，`amountType = income`，`projectId = 当前项目`。
- 如果对应某个“收定金/收尾款”事项，则同时写入 `lifeItemId` 并将事项标记完成。
- 项目已收金额只从实际收入账单聚合，不从事项聚合。

摄影投资支出：

- 器材、维修、进修等长期投入记录为普通支出账单，使用支出分类追踪。
- 如果支出明确属于某一单，则带 `projectId`。
- 如果支出是长期资产/能力投入，则不带 `projectId`，通过分类统计看整体摄影投入。

### 3.3 可选摄影分类包

默认只新增通用项目分类，不强行污染收支分类。

当用户首次套用“摄影接单”模板时，可提示一键添加以下收支分类：

```dart
// income
{'name': '摄影收入', 'icon': 'photo_camera'}

// expense
{'name': '摄影器材', 'icon': 'camera_enhance'}
{'name': '器材维修', 'icon': 'build'}
{'name': '摄影进修', 'icon': 'school'}
```

这些分类不是项目模型的一部分，只是模板体验增强。

---

## 4. 数据库设计

### 4.1 新增表 `projects`

```
id              INTEGER PK AUTO
title           TEXT NOT NULL (1-200)      -- 项目标题
categoryId      INTEGER NULLABLE           -- FK Categories(type='project') 项目类型
participant     TEXT NULLABLE              -- 客户/对象/参与人
projectStatus   TEXT DEFAULT 'planned'     -- 通用状态
startDate       DATETIME NULLABLE          -- 关键日期：拍摄日/出发日/活动日
endDate         DATETIME NULLABLE          -- 可选结束/交付日期
totalAmount     INTEGER NULLABLE           -- 约定总金额（分）
templateKey     TEXT NULLABLE              -- 如 photography_order，仅用于轻量模板识别
note            TEXT NULLABLE              -- 备注；拍摄类型等轻量字段可先写入这里
createdAt       DATETIME DEFAULT NOW
updatedAt       DATETIME DEFAULT NOW
deletedAt       DATETIME NULLABLE          -- 软删除
```

说明：

- `templateKey` 不参与业务强约束，只用于“是否由某模板创建”和后续 UI 文案。
- `startDate` 是通用关键日期，不命名为 `shootDate`。
- 拍摄类型先作为轻量文本存在 `note` 或模板表单内，不为它单独建字段。

### 4.2 新增表 `project_events`

```
id              INTEGER PK AUTO
projectId       INTEGER NOT NULL           -- FK Projects
eventType       TEXT NOT NULL              -- note/status_change/communication/milestone/delivery/other
title           TEXT NOT NULL (1-200)
description     TEXT NULLABLE
eventTime       DATETIME NOT NULL
isSystem        BOOLEAN DEFAULT FALSE       -- 状态变化等系统事件
createdAt       DATETIME DEFAULT NOW
```

说明：

- 不在 `project_events` 中重复保存收款金额。
- 收款、支出、待办完成等节点由时间线视图从 `BillRecords` 和 `LifeItems` 派生。
- 状态变更可以写入一条系统事件，方便项目历史追踪。

### 4.3 修改现有表

`LifeItems` 新增：

```
projectId       INTEGER NULLABLE
```

`BillRecords` 新增：

```
projectId       INTEGER NULLABLE
```

建议扩展 `LifeItem.itemType` 的约定值：

```
todo / bill / milestone / payment_due / delivery
```

现有旧值保持兼容。

### 4.4 索引与关系语义

建议索引：

```
projects(category_id, deleted_at)
projects(start_date, deleted_at)
projects(project_status, deleted_at)
life_items(project_id, due_time, deleted_at)
bill_records(project_id, bill_time, deleted_at)
project_events(project_id, event_time)
```

删除语义：

- 项目软删除：只隐藏项目，不删除关联事项/账单。
- 项目恢复：只恢复项目，不自动恢复已删除事项/账单。
- 项目硬删除：优先禁止删除仍有关联事项/账单的项目；或在确认后清空子记录 `projectId`。
- 事项/账单删除：不影响项目，只从项目详情和统计聚合中排除软删除记录。

### 4.5 Schema 迁移

`AppDatabase.schemaVersion` v2 -> v3：

```dart
if (from < 3) {
  await m.createTable(projects);
  await m.createTable(projectEvents);
  await m.addColumn(lifeItems, lifeItems.projectId);
  await m.addColumn(billRecords, billRecords.projectId);
  await _insertDefaultProjectCategories();
  await _createProjectIndexes();
}
```

默认项目分类：

```dart
static const project = [
  {'name': '摄影接单', 'icon': 'camera_alt'},
  {'name': '活动策划', 'icon': 'event'},
  {'name': '旅行规划', 'icon': 'flight'},
  {'name': '客户项目', 'icon': 'business_center'},
  {'name': '其他项目', 'icon': 'folder'},
];
```

---

## 5. 枚举与领域模型

### 5.1 ProjectStatus

使用通用状态：

```
planned     计划中
active      进行中
waiting     等待中
completed   已完成
cancelled   已取消
archived    已归档
```

摄影模板可在 UI 上映射为更自然的文案：

| 通用状态 | 摄影接单文案 |
|----------|--------------|
| planned | 咨询/待确认 |
| active | 已预约/执行中 |
| waiting | 等待选片/尾款/反馈 |
| completed | 已交付 |
| cancelled | 已取消 |
| archived | 已归档 |

### 5.2 ProjectEventType

```
note            备注
status_change   状态变更
communication   沟通记录
milestone       里程碑
delivery        交付记录
other           其他
```

不设置 `payment` 类型，避免和账单重复。支付节点由 `BillRecord` 派生进时间线。

### 5.3 ProjectSummary

项目详情页建议使用聚合 view model：

```dart
class ProjectSummary {
  final Project project;
  final int plannedReceivable; // pending/completed payment_due items sum
  final int incomeReceived;    // income bills sum
  final int expensePaid;       // expense bills sum
  final int receivableRemain;  // max(totalAmount - incomeReceived, 0)
  final int netAmount;         // incomeReceived - expensePaid
  final int openItemCount;
  final int completedItemCount;
}
```

计算口径：

- `incomeReceived` 只统计 `BillRecords.amountType == income`。
- `expensePaid` 只统计 `BillRecords.amountType == expense`。
- `receivableRemain` 优先使用 `Project.totalAmount - incomeReceived`。
- 如果 `totalAmount` 为空，则使用 `payment_due` 事项金额作为计划应收。

---

## 6. 数据层文件

```
lib/data/database/tables/
├── projects_table.dart
└── project_events_table.dart

lib/data/database/daos/
├── project_dao.dart
│   watchAll()
│   watchByStatus()
│   watchBetweenKeyDate()
│   watchByCategory()
│   getById()
│   insertOne()
│   updateOne()
│   softDeleteById()
│   restoreById()
│   hasLinkedRecords()
└── project_event_dao.dart
    watchByProject()
    insertOne()
    deleteById()

lib/data/repositories/
└── project_repository.dart
    createProject()
    createPhotographyProjectFromTemplate()
    updateProject()
    softDeleteProject()
    restoreProject()
    watchProjectSummary()
    watchProjectTimeline()

lib/data/database/daos/
├── life_item_dao.dart
│   watchByProjectId()
│   watchPaymentDueByProjectId()
└── bill_record_dao.dart
    watchByProjectId()
    watchSumByProjectId()
    watchMonthlySumsForRange()
    watchCategoryBreakdown()
    watchProjectIncomeForMonth()
```

---

## 7. Feature 模块

### 7.1 文件结构

```
lib/features/project/
├── pages/
│   ├── project_list_page.dart
│   ├── project_detail_page.dart
│   └── project_edit_page.dart
├── widgets/
│   ├── project_card.dart
│   ├── project_timeline.dart
│   ├── project_event_sheet.dart
│   ├── project_status_chip.dart
│   ├── project_financial_bar.dart
│   ├── project_section_header.dart
│   └── photography_template_fields.dart
└── providers/
    └── project_providers.dart
```

### 7.2 ProjectListPage

- 顶部状态筛选：全部 / 进行中 / 等待中 / 已完成 / 已归档。
- 分类筛选：摄影接单 / 活动策划 / 旅行规划 / 全部。
- 卡片展示：标题、状态、项目类型、参与人、关键日期、应收/已收进度。
- 排序：
  - 未完成项目按 `startDate` 升序。
  - 无日期项目靠后。
  - 已完成/归档项目按 `updatedAt` 降序。

### 7.3 ProjectEditPage

通用字段：

- 标题
- 项目类型
- 参与人/客户/对象
- 关键日期
- 可选结束/交付日期
- 约定总额
- 状态
- 备注

当项目类型为“摄影接单”或用户选择模板时，显示轻量摄影字段：

- 拍摄类型
- 定金金额、定金应收日期、是否已收
- 尾款金额、尾款应收日期
- 是否生成默认事项：拍摄日提醒、选片、修图交付、收尾款
- 是否添加摄影收支分类包

### 7.4 ProjectDetailPage

结构：

1. 概览区
   - 标题、状态、类型、参与人、关键日期。
   - 快捷操作：推进状态、添加事项、记一笔、添加事件。

2. 财务区
   - 应收、已收、待收。
   - 项目支出、净额。
   - 收款进度条。
   - 定金/尾款等应收事项的完成情况。

3. 事项区
   - 过滤：全部 / 待办 / 应收 / 交付 / 已完成。
   - 支持从项目内新增事项，自动带 `projectId`。

4. 账单区
   - 项目收入和支出流水。
   - 支持从项目内记账，自动带 `projectId`。
   - 如果从“收定金/收尾款”事项创建账单，自动带 `lifeItemId` 并完成事项。

5. 时间线区
   - 合并 `ProjectEvents`、`LifeItems`、`BillRecords`。
   - 按发生时间排序。
   - 同一笔收款不重复显示为事件和账单。

### 7.5 时间线合并规则

时间线来源：

| 来源 | 时间字段 | 展示类型 |
|------|----------|----------|
| ProjectEvents | eventTime | 沟通/备注/状态变更/交付记录 |
| LifeItems | dueTime / updatedAt | 应收计划、里程碑、待办完成 |
| BillRecords | billTime | 实际收入/支出 |

排序：

- 默认按时间倒序。
- 同一时间下，手动事件 > 实际账单 > 事项。

去重：

- 如果 `BillRecord.lifeItemId` 指向一个 `payment_due` 事项，时间线显示“已收定金/尾款”，不再额外显示“收定金事项完成”。

---

## 8. 与现有功能整合

### 8.1 路由与入口

路由：

```dart
GoRoute(
  path: '/projects',
  builder: (context, state) => const ProjectListPage(),
  routes: [
    GoRoute(path: 'new', builder: ... => ProjectEditPage()),
    GoRoute(path: ':id', builder: ... => ProjectDetailPage()),
    GoRoute(path: ':id/edit', builder: ... => ProjectEditPage()),
  ],
),
```

MVP 不新增底部 tab：

- 首页 QuickCreate 增加“建项目”。
- 首页日历项目关键日期可进入项目详情。
- 搜索页纳入项目结果。
- 设置页分类管理增加“项目”分类分段。

如果项目使用频率明显高于预期，再考虑底部 tab 或首页专属项目区。

### 8.2 首页 Agenda

`AgendaItemViewModel` 增加 `project` kind：

```dart
enum AgendaItemKind { lifeItem, billRecord, project }
```

`home_providers.dart`：

- 监听 `Projects.startDate` 落在可见日期范围内的项目。
- 合并项目、事项、账单。
- 项目在同日排序中低于实际账单，高于普通待办或按 UI 需要调整。

### 8.3 事项/账单创建流程

`LifeItemEditPage`：

- 新增可选“归属项目”下拉。
- 从项目详情进入时自动预填 `projectId`。
- `payment_due` 类型显示金额与收款方向。

`BillEditPage`：

- 新增可选“归属项目”下拉。
- 从项目详情进入时自动预填 `projectId`。
- 从项目应收事项创建时自动带 `lifeItemId`。

`BillNotifier.createFromLifeItem()`：

- 如果事项有 `projectId`，生成账单时同步写入 `projectId`。

### 8.4 搜索

搜索范围增加项目：

- 项目标题
- 参与人/客户
- 项目备注
- 项目分类名

搜索结果点击进入 `/projects/:id`。

### 8.5 备份与回收站

备份 JSON 升级为 version 2：

```json
{
  "version": 2,
  "categories": [],
  "projects": [],
  "projectEvents": [],
  "lifeItems": [],
  "billRecords": []
}
```

导入顺序：

1. categories
2. projects
3. lifeItems
4. billRecords
5. projectEvents

ID 映射：

- `categoryId`
- `projectId`
- `lifeItemId`

兼容：

- version 1 备份仍可导入，项目数据为空。

回收站：

- 增加项目分组。
- 恢复项目不自动恢复子事项/账单。
- 删除项目前提示关联数据仍会保留。

---

## 9. 统计增强

### 9.1 现状

当前统计页偏单月、文字为主，需要补充趋势、占比和对比。

### 9.2 新增视图

1. 多月收支趋势
   - 近 6 个月收入/支出双线。
   - 支持点击月份切换当前月。
   - 数据源：`watchMonthlySumsForRange(start, end)`。

2. 分类占比
   - 支出 Top 5 + 其他。
   - 收入 Top 5 + 其他。
   - 数据源：`watchCategoryBreakdown(month, amountType)`。

3. 月度环比
   - 收入环比、支出环比、结余变化。
   - 处理上月为 0 的情况：显示“新增/无上月数据”，不显示无限百分比。

4. 项目统计卡片
   - 本月进行中项目数。
   - 本月完成项目数。
   - 本月项目收入。
   - 可选：项目净额 Top 3。

5. 摄影经营轻量视角
   - 不单独做页面。
   - 通过项目分类“摄影接单”和收支分类“摄影收入/摄影器材/器材维修/摄影进修”共同形成视角。
   - 后续可扩展为筛选条件：按项目类型过滤统计。

### 9.3 文件

```
lib/features/statistics/
├── pages/statistics_page.dart
├── providers/statistics_providers.dart
└── widgets/
    ├── trend_line_chart.dart
    ├── category_rank_list.dart
    ├── month_compare_card.dart
    └── project_stats_card.dart
```

---

## 10. 实施阶段

### Phase 1 - 数据层与迁移

1. 新增 `ProjectStatus`、`ProjectEventType`。
2. 新增 `projects_table.dart`、`project_events_table.dart`。
3. `LifeItems`、`BillRecords` 新增 `projectId`。
4. `app_database.dart` 注册新表/DAO，schema v2 -> v3。
5. 新增项目相关索引。
6. 新增默认项目分类。
7. 新增 `project_dao.dart`、`project_event_dao.dart`。
8. 扩展 `life_item_dao.dart`、`bill_record_dao.dart` 的项目查询与统计聚合。
9. 新增 `project_repository.dart`。
10. 运行 `build_runner`。
11. 写迁移和 DAO 单元测试。

### Phase 2 - 项目核心 UI

12. 新增 `project_providers.dart`。
13. 实现 `ProjectEditPage` 通用项目表单。
14. 实现 `ProjectListPage`。
15. 实现 `ProjectDetailPage`：概览、财务、事项、账单、时间线。
16. 实现状态标签、财务进度条、时间线组件、添加事件弹窗。
17. 注册项目路由。

### Phase 3 - 轻量摄影模板

18. 新增摄影模板字段组件。
19. 创建项目时支持套用摄影模板。
20. 自动生成定金、尾款、拍摄、选片、交付等事项。
21. 支持从应收事项创建实际收款账单。
22. 首次使用摄影模板时提供可选收支分类包。

### Phase 4 - 现有功能整合

23. `LifeItemEditPage` 增加归属项目选择。
24. `BillEditPage` 增加归属项目选择。
25. `BillNotifier.createFromLifeItem()` 同步项目归属。
26. 首页 Agenda 合并项目关键日期。
27. QuickCreate 增加“建项目”。
28. 搜索扩展项目结果。
29. 分类管理增加“项目”分类。

### Phase 5 - 数据安全与统计

30. `BackupService` 支持 version 2、项目、项目事件、项目关系映射。
31. `RecycleBinPage` 支持项目恢复。
32. 统计页新增多月趋势、分类占比、环比对比、项目统计卡片。
33. 处理空数据、上月为 0、大金额、跨年月份。

### Phase 6 - 验证与收尾

34. 跑单元测试、widget 测试、集成 smoke。
35. 手动验证摄影接单完整流程。
36. 验证无项目事项/账单不受影响。
37. 验证备份恢复后项目关系完整。

---

## 11. 边缘情况、故障模式与风险

### 边缘情况

- 项目无关键日期：不显示在首页日历，但可在项目列表中看到。
- 项目无总金额：收款进度用应收事项金额聚合，或显示“未设置总额”。
- 定金已收但没有应收事项：项目已收仍正常统计。
- 尾款应收事项逾期：事项系统负责展示逾期，项目详情同步展示。
- 账单归属项目但分类为空：项目统计仍计算金额，分类统计归入“未分类”。
- 项目被删除后子事项/账单仍存在：子记录保留，项目恢复后关系仍可用。
- 备份导入时项目分类不存在：先导入/创建分类，再映射项目。
- 旧版备份没有项目字段：按 version 1 兼容导入。

### 风险

- 时间线重复：如果同时创建 payment event 和 bill record，会重复展示收款。解决：支付只来自账单。
- 项目状态过行业化：会影响旅行/活动等通用场景。解决：状态使用通用枚举，模板只改文案。
- 摄影分类污染通用用户：解决：收支分类包改为模板可选。
- 统计性能下降：解决：按项目和月份建索引，聚合在 SQL 完成。
- 备份遗漏关系：解决：version 2 明确导出项目、事件、`projectId`、`lifeItemId`。
- 删除语义混乱：解决：软删除项目不动子记录，硬删除前检测关联。

---

## 12. 验证方式与指标

### 自动化测试

- `project_migration_test`
  - v2 数据升级到 v3 后旧数据仍存在。
  - 新列 `projectId` 默认为空。

- `project_repository_test`
  - 创建普通项目。
  - 创建摄影模板项目并生成事项。
  - 项目软删除、恢复。

- `project_finance_summary_test`
  - 定金/尾款应收事项不计入已收。
  - 实际收入账单计入已收。
  - 项目支出和净额计算正确。

- `project_timeline_merge_test`
  - 手动事件、事项、账单按时间合并。
  - `lifeItemId` 关联的收款不重复展示。

- `backup_service_project_test`
  - version 2 导出导入后项目、事件、事项、账单关系保持。
  - version 1 备份仍可导入。

- `home_agenda_project_test`
  - 项目关键日期出现在首页对应日期。
  - 无日期项目不污染日历。

- `statistics_project_test`
  - 多月趋势跨年正确。
  - 分类占比 Top 5 + 其他正确。
  - 上月为 0 时环比文案正确。

### 手动验收流程

1. 启动旧数据库，确认迁移成功。
2. 创建“张先生婚礼拍摄”项目，套用摄影模板。
3. 确认自动生成定金、拍摄日、选片、修图交付、尾款事项。
4. 从“收定金”事项创建收入账单，确认事项完成、项目已收增加。
5. 创建一笔项目支出，确认项目净额变化。
6. 添加沟通记录和交付记录，确认时间线排序清晰。
7. 首页日历显示拍摄日项目。
8. 创建旅行规划项目，确认没有摄影专用字段强制出现。
9. 导出备份、清库导入，确认项目关系完整。
10. 删除并恢复项目，确认事项/账单保留。

### 性能指标

- 10k 条账单、2k 个事项、500 个项目下：
  - 项目列表首屏加载小于 500ms。
  - 项目详情聚合小于 300ms。
  - 统计页聚合小于 800ms。
- 首页日历切换月份无明显卡顿。

---

## 13. 内部代理评审

### Builder（构建者）

方案沿用现有 Drift 表、DAO、Repository、Riverpod Provider、Feature Page 结构，新增面清晰。轻量摄影模板通过创建项目时批量生成事项实现，不需要引入复杂模板表。

### Critic（评论者）

原计划最大问题是 `ProjectEvents.payment` 可能和 `BillRecords` 重复、摄影状态过专用、备份/回收站放得太晚。修订后把支付节点统一交给账单，把状态改为通用枚举，并把数据安全纳入上线前必做。

### Test（测试者）

关键测试不只是页面能打开，而是关系能闭环：模板生成事项、事项生成账单、账单回写项目统计、时间线不重复、备份恢复关系不丢。

### Performance（性能）

项目模块会增加首页、统计、详情页的组合查询。必须建立 `projectId`、日期、软删除相关索引；统计用 SQL 聚合，不使用全量列表折叠。

---

## 14. 最终建议

MVP 推荐范围：

- 做通用项目容器。
- 做轻量摄影接单模板。
- 做项目详情财务汇总和合并时间线。
- 做项目与事项/账单的双向入口。
- 做统计增强的核心三件事：趋势、分类占比、环比。
- 必做备份/恢复/回收站。

暂不做：

- 客户库/联系人 CRM。
- 合同、发票、报价单。
- 动态字段系统。
- 多人协作。
- 项目附件管理。
- 库存/器材资产折旧。

置信度：0.88。

主要不确定因素：

- 摄影模板默认生成的事项间隔是否符合真实流程，需要实际使用后微调。
- “拍摄类型”是否长期只放备注足够；如果后续需要按拍摄类型统计，再升级为独立字段或模板字段表。
- 项目入口是否需要底部 tab，取决于上线后项目使用频率。

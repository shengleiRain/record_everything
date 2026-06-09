# 通用项目模块 + 统计增强规划

> 创建日期：2026-06-10
> 状态：规划中，待实施

## 背景

用户有摄影接单的高频场景，需要一个完整的时间脉络追踪。同时希望模块通用化，能复用于活动策划、旅行规划等类似结构化场景。设计核心：**项目是容器，事项和账单可归属于项目**。

## 参考应用

| 应用 | 模式 | 参考 |
|------|------|------|
| Todoist / Things 3 | Project 包含 Tasks，项目是分组容器 | 事项归属项目 |
| 随手记（项目记账） | 记账可归集到项目/旅行，查看项目总收支 | 账单归属项目 |
| Asana / Linear | Project 包含 Issues，可看时间线 | 项目时间线 |
| Notion（Relation） | 数据库之间关联，灵活归属 | 多实体关联 |

## 核心设计：项目作为容器

**现状**：LifeItems 和 BillRecords 是平行的两个实体，通过 `lifeItemId` FK 单向关联。

**改进**：新增 `Projects` 表 + `ProjectEvents` 表，LifeItems 和 BillRecords 各加 `projectId` FK。

```
Project (项目容器)
├── LifeItems (关联的事项)     ← 现有表加 projectId 列
├── BillRecords (关联的账单)   ← 现有表加 projectId 列
└── ProjectEvents (时间线记录) ← 新表
```

**摄影接单场景举例**：
1. 创建项目 "张先生婚礼拍摄"，type=摄影接单，日期=7/15，约定总价 ¥5,000
2. 创建事项 "拍摄日提醒"（归属该项目，dueTime=7/15，设提醒）
3. 创建事项 "选片"（归属该项目，dueTime=7/20）
4. 创建事项 "修图交付"（归属该项目，dueTime=8/1）
5. 收定金 → 创建账单 "定金 ¥2,000"（归属该项目，income）
6. 添加时间线 "客户咨询，确定拍摄风格为纪实风"
7. 收尾款 → 创建账单 "尾款 ¥3,000"（归属该项目，income）
8. 添加时间线 "已交付全部精修照片"

**项目详情页自动汇总**：
- 应收 ¥5,000 | 已收 ¥2,000 | 待收 ¥3,000
- 关联事项列表（拍摄日/选片/修图，带状态）
- 关联账单列表（定金/尾款）
- 时间线（按时间排列的事件流）

**无项目的 items/bills 完全不受影响**，向后兼容。

---

## 一、数据库设计

### 新增表 `projects`

```
id              INTEGER PK AUTO
title           TEXT NOT NULL (1-200)      -- 项目标题
categoryId      INTEGER NULLABLE           -- FK Categories(type='project') 项目类型
participant     TEXT NULLABLE              -- 客户/拍摄对象/参与人
projectStatus   TEXT DEFAULT 'inquiry'     -- 项目状态（见枚举）
startDate       DATETIME NULLABLE          -- 关键日期（拍摄日/出发日等）
totalAmount     INTEGER NULLABLE           -- 约定总金额（分），用于跟踪收款进度
note            TEXT NULLABLE              -- 备注
createdAt       DATETIME DEFAULT NOW
updatedAt       DATETIME DEFAULT NOW
deletedAt       DATETIME NULLABLE          -- 软删除
```

### 新增表 `project_events`（时间线/事件流）

```
id              INTEGER PK AUTO
projectId       INTEGER NOT NULL           -- FK Projects
eventType       TEXT NOT NULL              -- 事件类型（见枚举）
title           TEXT NOT NULL (1-200)      -- 事件摘要
description     TEXT NULLABLE              -- 详情
amount          INTEGER NULLABLE           -- 关联金额（分，可选）
eventTime       DATETIME NOT NULL          -- 事件发生时间
createdAt       DATETIME DEFAULT NOW
```

### 修改现有表

**LifeItems** 新增列：
```
projectId       INTEGER NULLABLE           -- FK Projects
```

**BillRecords** 新增列：
```
projectId       INTEGER NULLABLE           -- FK Projects
```

### Schema 迁移

`AppDatabase.schemaVersion` v2 → v3：
```dart
if (from < 3) {
  await m.createTable(projects);
  await m.createTable(projectEvents);
  await m.addColumn(lifeItems, lifeItems.projectId);
  await m.addColumn(billRecords, billRecords.projectId);
  await _insertDefaultProjectCategories();
}
```

---

## 二、枚举与分类

### 新增枚举

**ProjectStatus**（`lib/domain/enums/project_status.dart`）：
```
inquiry(咨询中) → booked(已预约) → in_progress(进行中) → delivered(已交付) → completed(已完成)
/ cancelled(已取消)
```

**ProjectEventType**（`lib/domain/enums/project_event_type.dart`）：
```
status_change(状态变更) / note(备注) / payment(收款) / milestone(里程碑) /
communication(沟通记录) / delivery(交付) / other(其他)
```

### 分类扩展

`Categories` 新增 `type='project'`：
```dart
static const project = [
  {'name': '摄影接单', 'icon': 'camera_alt'},
  {'name': '活动策划', 'icon': 'event'},
  {'name': '旅行规划', 'icon': 'flight'},
  {'name': '客户项目', 'icon': 'business_center'},
  {'name': '其他项目', 'icon': 'folder'},
];
```

收支分类新增：
```dart
// income
{'name': '摄影收入', 'icon': 'photo_camera'},
// expense
{'name': '摄影器材', 'icon': 'camera_enhance'},
{'name': '摄影培训', 'icon': 'school'},
```

用户可在设置→分类管理中自行添加更多项目类型。

---

## 三、数据层文件

```
lib/data/database/tables/
├── projects_table.dart                   ← 新增
└── project_events_table.dart             ← 新增

lib/data/database/daos/
├── project_dao.dart                      ← 新增
│   watchAll(), watchByStatus(), watchUpcoming(),
│   getById(), insertOne(), updateOne(),
│   softDeleteById(), restoreById()
└── project_event_dao.dart                ← 新增
    watchByProject(), insertOne(), deleteById()

lib/data/repositories/
└── project_repository.dart               ← 新增

lib/data/database/daos/
├── life_item_dao.dart                    -- 新增 watchByProjectId()
└── bill_record_dao.dart                  -- 新增 watchByProjectId(),
                                           watchSumForMonthRange(),
                                           watchCategoryBreakdown()

lib/data/database/app_database.dart       -- 注册新表/DAO，v3 迁移
```

---

## 四、Feature 模块

### 文件结构

```
lib/features/project/                     ← 新增 feature 模块
├── pages/
│   ├── project_list_page.dart            -- 项目列表（状态 Tab + 分类筛选）
│   ├── project_detail_page.dart          -- 项目详情（汇总 + 事项 + 账单 + 时间线）
│   └── project_edit_page.dart            -- 新建/编辑项目表单
├── widgets/
│   ├── project_card.dart                 -- 列表卡片
│   ├── project_timeline.dart             -- 竖向时间线组件
│   ├── project_event_sheet.dart          -- 添加事件底部弹窗
│   ├── project_status_chip.dart          -- 状态标签
│   └── project_financial_bar.dart        -- 收款进度条（已收/应收）
└── providers/
    └── project_providers.dart
```

### 核心页面设计

**ProjectListPage**：
- 顶部状态 Tab（全部/进行中/已完成）
- 分类筛选（摄影接单/活动策划/全部等）
- 卡片：标题 + 状态标签 + 参与人 + 关键日期 + 收款进度
- 按 startDate 排序

**ProjectDetailPage**：
- 顶部 Hero 卡片（标题 + 状态 + 类型 + 参与人 + 关键日期）
- **收款进度条**：已收 / 约定总额（从关联 income bills 聚合）
- **关联事项**：该项目下的 LifeItems 列表（可跳转详情、可新增）
- **关联账单**：该项目下的 BillRecords 列表（可新增收入/支出）
- **时间线**：ProjectEvents + 关联事项/账单的创建事件，按时间排列
- 操作按钮：推进状态、添加事件、添加事项、添加账单

**ProjectEditPage**：
- 项目信息区块：标题、分类（项目类型）、参与人、关键日期
- 金额信息区块：约定总额
- 备注
- 复用现有 `_SectionCard` + `AppDropdownField` 模式

### 路由

```dart
// app_router.dart ShellRoute 内新增
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

不新增底部 tab，从首页快捷创建和 agenda 入口 push 导航。

---

## 五、与现有功能整合

### 首页整合

**AgendaItemViewModel** 新增 `project` kind：
```dart
enum AgendaItemKind { lifeItem, billRecord, project }

// 新增工厂方法
factory AgendaItemViewModel.fromProject(Project project)
```

**home_providers.dart `_watchAgendaItems`**：
- 新增第三个 Stream：监听 startDate 落在范围内的 Projects
- 合并到 combined list 中
- 首页日历自然显示项目关键日期

**QuickCreateSheet**：新增「新建项目」入口卡片

### 事项/账单创建流程

- `LifeItemEditPage` 新增可选的「归属项目」下拉选择
- `BillEditPage` 新增可选的「归属项目」下拉选择
- 在项目详情页内创建事项/账单时自动填入 projectId

### 统计整合

项目收支通过 BillRecord 自动纳入现有统计，无需特殊处理。

---

## 六、统计增强

### 现状

当前 `statistics_page.dart` 仅展示单月数据：4 个摘要格 + 3 柱图 + 4 行分类文字 + 预测文字 + 预算文字。

### 增强内容

**1. 多月收支趋势折线图**（利用已有 fl_chart）
- 近 6 个月收入/支出双线趋势
- 点击月份节点跳转对应月
- 数据源：新增 `BillRecordDAO.watchSumForMonthRange(start, end, amountType)`

**2. 分类占比图**
- 支出 Top 5 分类 + 其他，带进度条和百分比
- 收入 Top 5 分类 + 其他
- 数据源：新增 `BillRecordDAO.watchCategoryBreakdown(month, amountType)` 按 categoryId 分组求和

**3. 月度环比对比**
- 收入环比 ↑↓%、支出环比 ↑↓%、结余变化
- 用颜色+箭头直观展示

**4. 项目统计卡片**（项目模块完成后）
- 本月进行中/已完成项目数
- 本月项目收入总计

### 文件

```
lib/features/statistics/
├── pages/statistics_page.dart            -- 重构，插入新卡片
├── providers/statistics_providers.dart   -- 新增 providers
└── widgets/                              ← 新增目录
    ├── trend_line_chart.dart             -- fl_chart 折线图
    ├── category_rank_list.dart           -- 分类排行（带进度条）
    └── month_compare_card.dart           -- 环比对比
```

---

## 七、实施阶段

### Phase 1 - 数据层
1. 新增枚举 `project_status.dart`、`project_event_type.dart`
2. 新增表 `projects_table.dart`、`project_events_table.dart`
3. 修改 `app_database.dart`：注册新表/DAO，v2→v3 迁移
4. 新增 `project_dao.dart`、`project_event_dao.dart`
5. `life_item_dao.dart` 新增 `watchByProjectId()`
6. `bill_record_dao.dart` 新增 `watchByProjectId()`、`watchSumForMonthRange()`、`watchCategoryBreakdown()`
7. 新增 `project_repository.dart`
8. 新增默认分类
9. 运行 `build_runner` 重新生成
10. 启动验证迁移成功

### Phase 2 - 项目模块
11. `project_providers.dart`
12. `ProjectEditPage`
13. `ProjectDetailPage`（汇总 + 关联事项 + 关联账单 + 时间线）
14. `ProjectEventSheet`、`ProjectCard`、`ProjectTimeline`、`ProjectStatusChip`、`ProjectFinancialBar`
15. `ProjectListPage`
16. 注册路由

### Phase 3 - 现有功能整合
17. LifeItem/BillRecord 新增 projectId 列 + 迁移
18. `LifeItemEditPage` / `BillEditPage` 增加「归属项目」选择
19. `AgendaItemViewModel` 增加 project kind
20. `_watchAgendaItems` 合并项目关键日期
21. `QuickCreateSheet` 增加「新建项目」入口

### Phase 4 - 统计增强
22. `trend_line_chart.dart`（6 月折线图）
23. `category_rank_list.dart`（分类排行）
24. `month_compare_card.dart`（环比对比）
25. 重构 `statistics_page.dart`

### Phase 5 - 收尾
26. `BackupService` 扩展
27. `RecycleBinPage` 扩展
28. 搜索扩展
29. 全流程测试

---

## 八、验证方式

- 启动 app，确认 v2→v3 迁移成功，原有数据不受影响
- 创建摄影接单项目，关联事项和账单
- 项目详情页显示收款进度（已收/应收）
- 首页日历显示项目关键日期
- 事项/账单 Tab 内可看到归属项目的记录
- 统计页显示多月趋势、分类排行、环比对比
- 创建其他类型项目（活动策划等）确认通用性
- 测试无项目的事项/账单完全不受影响
- 测试软删除和回收站恢复
- 测试备份恢复

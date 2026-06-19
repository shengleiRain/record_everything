# 生活事项 (Life Items)

一款统一的生活管理应用，将任务、账单、提醒和项目管理融合到一个简洁的界面中。核心设计理念是将所有生活事务统一为"生活事项"模型——无论是待办任务、账单到期、会员续费、证件过期还是项目里程碑，都可以在一个地方管理。

## 功能特性

### 首页仪表盘
- 可折叠周/月日历，支持左右切换月份
- 今日待办事项卡片、即将到期事项卡片
- 月度收支概览（收入、支出、待收、逾期统计）
- 选中日期的日程列表，自动合并事项与账单并去重
- 快速创建入口（一键新建事项或账单）

### 生活事项管理
- 完整的 CRUD 操作（创建、查看、编辑、删除）
- 状态机流转：`待处理 → 已完成 / 已取消`，终态可重新打开
- 8 种筛选条件：全部、逾期、今天、未来 7 天、重复、有金额、有提醒、已完成
- 完成操作支持多种模式：
  - 仅完成
  - 完成并生成账单
  - 完成并生成账单 + 自动生成下期事项
  - 延期（推迟到期日期）
  - 取消
- 左滑快捷操作（完成、延期）
- 事项详情底部弹窗

### 账单记录
- 收入/支出追踪，按月查看
- 按日分组显示
- 4 种筛选：全部、支出、收入、订阅
- 月度汇总卡片（收入、支出、预算使用情况）
- 支持关联生活事项或项目
- 金额以整数分存储（如 12.34 元 = 1234），避免浮点精度问题

### 项目管理
- 完整的项目生命周期管理
- 状态机流转：`进行中 → 已完成 → 已归档`，`进行中 → 已取消`，终态可重新激活
- 项目内含生活事项（作为步骤/里程碑）和独立账单记录
- 时间线视图：按时间顺序展示事项和账单
- 财务概览：已收收入、待收应收、支出统计
- 支持从模板创建项目
- 项目事件记录（备注、状态变更、沟通、里程碑、交付等）

### 项目模板
- 可复用的项目模板，包含有序步骤
- 步骤支持灵活的日期锚点：
  - 关键日期偏移（如婚礼前 7 天）
  - 创建日期偏移（如项目创建后 30 天）
  - 绝对日期
- 修改项目关键日期时，自动重新计算未手动编辑的步骤日期
- 内置 2 个摄影行业模板（婚纱摄影、证件摄影）
- 支持创建、编辑、复制、删除自定义模板

### 事项模板
- 快速创建常见生活事项的模板
- 6 个内置模板：会员续费、证件过期、药品补货、家庭账单、保修到期、消耗品更换
- 关键词推荐：输入标题时自动匹配并推荐相关模板
- 支持自定义模板管理

### 统计分析
- 月度收支统计与预算使用率
- 事项完成率与逾期统计
- 30 天支出预测
- 6 个月收支趋势图表
- 同比环比分析
- 分类占比（Top 5 + 其他）
- 项目统计（活跃/已完成数量、项目收入）
- 预算风险分析

### 搜索
- 全文搜索覆盖生活事项、账单记录和项目
- 按日期倒序排列结果
- 搜索结果支持滑动操作（完成/延期事项，编辑/删除账单）
- 输入防抖优化

### 分类管理
- 支持收入、支出、事项、项目四种分类类型
- 分类 CRUD 操作
- 分类合并（自动重新分配所有引用）
- 分类隐藏/置顶
- 默认分类保护（不可删除，只能隐藏）
- 使用中的非默认分类受保护（防止删除正在使用的分类）

### 提醒通知
- 基于 `flutter_local_notifications` 的本地通知
- 创建/更新事项时自动调度提醒
- 完成/删除事项时自动取消提醒
- 数据导入后自动重建所有未来提醒

### 日历集成
- 通过 `add_2_calendar` 插件将事项导出到设备原生日历

### 数据安全
- JSON 格式导出/导入备份
- 版本化备份架构（v1-v6），向后兼容
- 导入时自动去重（基于标题+时间+金额匹配）
- 备份包含：分类、事项模板、项目模板、项目模板步骤、项目、生活事项、账单记录、项目事件

### 回收站
- 软删除模式覆盖所有主要实体（生活事项、账单记录、项目）
- 支持恢复或永久删除
- 删除的分类在回收站中可查看

### 设置
- 分类管理入口
- 提醒权限设置
- 数据导入/导出
- 回收站管理

### 智能输入
- 自然语言一句话创建事项或账单（"明天3点开会，午餐花了25"）
- 拍照 / 选图识图记账（端侧 ML Kit OCR，离线可用）
- 从其他 App 系统分享文字直接解析
- 语音输入（复用系统语音键盘）
- 本地规则引擎优先解析（覆盖 95% 高频输入），复杂输入可配置云端大模型兜底
- 设置 → AI 助手：BYOK 自带 API Key（通义千问 / 智谱 / DeepSeek / 自定义）
- 解析结果经草稿确认页确认后落库，AI 永不直接写入数据库
- 数据不上传服务器，云端仅在开启且配置后按需调用
- 当前仅 Android；iOS 支持见 `docs/superpowers/specs/2026-06-19-smart-entry-design.md` §14

## 技术栈

| 技术 | 用途 |
|------|------|
| Flutter 3.41 / Dart 3.11 | 跨平台 UI 框架 |
| Riverpod 2.6.1 | 状态管理（Provider + StreamProvider + NotifierProvider） |
| Drift 2.22.1 + SQLite | 本地数据库（10 张表，Schema 版本 10） |
| go_router 14.8.1 | 声明式路由（5 Tab ShellRoute + 子路由） |
| flutter_local_notifications 18.0.1 | 本地提醒通知 |
| fl_chart 0.69.2 | 统计图表 |
| intl 0.19.0 | 日期/时间格式化 |
| add_2_calendar 3.1.0 | 日历集成 |
| file_picker 11.0.2 | 文件选择器（备份导入/导出） |
| shared_preferences 2.5.5 | 轻量级本地存储 |

## 项目结构

```
lib/
  main.dart                           # 应用入口，ProviderScope 配置
  app.dart                            # MaterialApp.router，主题配置
  core/
    theme/                            # AppColors（Material 3 绿色主题）、AppTheme
    router/                           # GoRouter 路由配置（ShellRoute 5 Tab）
    utils/                            # MoneyFormatter、DateFormatter、DialogHelper
    constants/                        # 默认分类、模板 Key、图标选项
    notifications/                    # NotificationService、ReminderScheduler
    calendar/                         # CalendarEventService、Add2CalendarGateway
    widgets/                          # 通用组件（滑动操作、卡片部件、章节卡片等）
  data/
    database/
      app_database.dart               # Drift 数据库定义（Schema v10，迁移逻辑，默认数据播种）
      database_provider.dart          # Riverpod 数据库 Provider
      tables/                         # 10 张表定义
      daos/                           # 7 个 DAO（含代码生成文件）
    repositories/                     # 6 个 Repository（CRUD + 业务逻辑）
  domain/
    enums/                            # 6 个枚举（ItemStatus、ProjectStatus、AmountType 等）
    models/                           # RepeatRule 等领域模型
  features/
    home/                             # 首页（日历、日程、快速创建）
    life_item/                        # 生活事项（列表、编辑、详情、完成操作）
    bill/                             # 账单（列表、编辑、详情、分组）
    project/                          # 项目（列表、详情、编辑、模板、步骤编辑器）
    statistics/                       # 统计分析（趋势、分类、项目、预测）
    settings/                         # 设置（分类管理、数据安全、回收站）
    search/                           # 搜索服务与页面
  shared/widgets/                     # 共享组件（下拉框、保存按钮、表单混入等）
test/                                 # 32 个单元/组件测试文件
integration_test/                     # 集成测试
.maestro/                             # 11 个 Maestro E2E 测试流程
tools/                                # 自定义 lint 规则插件
```

## 数据库架构

10 张表，Schema 版本 10：

| 表名 | 列数 | 说明 |
|------|------|------|
| LifeItems | 21 | 生活事项（标题、金额、到期时间、提醒、重复规则、状态、项目关联等） |
| BillRecords | 12 | 账单记录（标题、金额、类型、时间、事项关联、项目关联等） |
| Categories | 8 | 分类（名称、类型、图标、默认/隐藏/置顶标记） |
| Accounts | 5 | 账户（名称、类型、默认标记） |
| MonthlyBudgets | 5 | 月度预算（月份、金额） |
| Projects | 12 | 项目（标题、状态、日期、金额、模板关联等） |
| ProjectEvents | 7 | 项目事件（类型、标题、描述、时间） |
| ProjectTemplates | 8 | 项目模板（名称、Key、分类、备注） |
| ProjectTemplateSteps | 10 | 项目模板步骤（标题、金额、日期锚点偏移、排序） |
| ItemTemplates | 13 | 事项模板（名称、Key、金额、偏移天数、重复规则、关键词） |

## 快速开始

1. 安装 Flutter：https://docs.flutter.dev/get-started/install
2. 克隆仓库
3. 安装依赖：
   ```bash
   flutter pub get
   ```
4. 生成 Drift 代码：
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. 运行应用：
   ```bash
   flutter run
   ```

## 开发指南

### 代码生成

修改表/DAO 定义后重新生成 Drift 代码：
```bash
dart run build_runner build --delete-conflicting-outputs
```

开发时监听文件变化自动重新生成：
```bash
dart run build_runner watch --delete-conflicting-outputs
```

### 运行测试

单元和组件测试：
```bash
flutter test
```

集成测试（需要连接设备或模拟器）：
```bash
flutter test integration_test/app_smoke_test.dart
```

Maestro E2E 测试：
```bash
maestro test .maestro/
```

### 自定义 Lint 规则

项目包含一个自定义 lint 插件 `avoid_local_disposable_in_function`，防止在函数/方法内部创建可释放的 Flutter 资源（TextEditingController、ScrollController、FocusNode 等），确保资源在 State 类级别管理。

## 关键设计决策

- **金额以整数分存储**：12.34 元存储为 1234，避免浮点精度问题
- **逾期动态计算**：查询时根据当前时间判断，不存储在数据库中
- **事项与账单分离**：事项代表未来的任务/义务，账单代表实际发生的交易
- **软删除模式**：所有主要实体支持软删除，通过回收站恢复或永久删除
- **状态机模式**：事项和项目使用严格的状态机管理状态流转
- **重复规则字符串**：支持每日、每周、每月、每年和自定义天数（`every:N:days`）
- **项目日期锚点**：步骤日期基于关键日期或创建日期自动计算，修改关键日期时自动重新计算
- **分类保护**：默认分类不可删除（仅可隐藏），使用中的分类受保护
- **备份去重**：导入时基于标题+时间+金额自动去重
- **Provider 架构**：Repository 和 Service 使用 Provider，数据流使用 StreamProvider，UI 状态使用 StateProvider，写操作使用 NotifierProvider

## 状态机

### 生活事项状态
```
pending（待处理）
  ├── → completed（已完成）
  └── → cancelled（已取消）

completed / cancelled → pending（重新打开）
archived（已归档）为终态，不可变更
```

### 项目状态
```
active（进行中）
  ├── → completed（已完成）
  └── → cancelled（已取消）

completed → archived（已归档）
completed / cancelled / archived → active（重新激活）
```

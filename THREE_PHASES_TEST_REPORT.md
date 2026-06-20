# 三阶段功能 Android 模拟器测试报告

- **测试日期**：2026-06-20
- **设备**：Android 模拟器 `sdk gphone64 x86 64`（`emulator-5554`，Android 16 / API 36）
- **构建模式**：Debug（Release 因 ML Kit R8 missing-class 失败，详见 §5）
- **测试文件**：
  - `integration_test/three_phases_integration_test.dart`（功能断言，**7/7 全部通过**）
  - `integration_test/screenshot_each_phase_test.dart`（可视化截图，**8 张全部生成**）
- **总览**：三阶段功能（智能录入 / 桌面与快捷触达 / 智能洞察与自动化）在 Android 模拟器上全部验证通过。

## 1. 测试范围

| 阶段 | 功能 | 验证方式 |
|------|------|---------|
| 阶段一 · 智能录入 | 自然语言解析 → 草稿确认 → 落库；空输入守卫；BYOK AI 助手设置页 | 集成测试 + 截图 |
| 阶段二 · 桌面与快捷触达 | `WidgetSyncService` 写入 `home_widget` 的数据格式；Deep Link `lifeitems://` URI 映射 | 集成测试 |
| 阶段三 · 智能洞察与自动化 | 统计页每日/分类趋势图表渲染；账单编辑页自动分类推荐 chip | 集成测试 + 截图 |

> **说明**：OCR 识图、语音输入、系统分享接收、真实桌面 Widget 拖拽依赖真机/外部环境，不在可程序化驱动范围内；其底层服务（解析管道、`WidgetSyncService`、Deep Link 映射）已通过集成测试覆盖。

## 2. 阶段一：智能录入（Smart Entry）✅

### 集成测试（3/3 通过）

| 测试 | 结果 | 说明 |
|------|------|------|
| 自然语言解析 → 草稿确认页 → 落库成功 | ✅ | 输入「明天3点开会，午餐花了25」→ 解析 → 跳草稿确认页 → 全部保存 → 数据库出现「午餐」账单（amount=2500 分，即 25 元） |
| 空输入解析不触发跳转 | ✅ | 输入仅空白时点「解析」按钮，`_parse` 内部 `return`，仍停留在快速输入页 |
| BYOK AI 助手设置页可达且渲染 | ✅ | 设置 → AI 助手，页面含「启用智能输入」「提供商」「保存」 |

### 关键验证点
- **多入口汇聚单管道**：首页「新增」→ 快速创建面板「智能输入」横幅 → `/smart-entry/input`。
- **AI 永不直接落库**：解析结果必经草稿确认页（`解析结果` AppBar），用户点「保存全部 N 条」后才落库。
- **金额整数分存储**：25 元落库为 `amount=2500`，与设计一致。
- **BYOK 默认未启用**：云端为 `NoopCloudParser`，本地规则引擎承载主流程。

### 截图（`screenshots/phase_screenshots/`）
- `p1_quick_create_sheet.png` — 快速创建面板，顶部「智能输入」横幅
- `p1_smart_entry_input.png` — 快速输入页（输入框 + 解析/拍照/语音按钮）
- `p1_draft_confirm.png` — 草稿确认页（解析结果）
- `p1_saved_snackbar.png` — 保存后「已保存 N 条」提示
- `p1_ai_assistant_settings.png` — BYOK AI 助手设置页

## 3. 阶段二：桌面与快捷触达（App Shortcuts + Widget）✅

### 集成测试（2/2 通过）

| 测试 | 结果 | 说明 |
|------|------|------|
| `WidgetSyncService` 写入 `home_widget` 的 key/value 格式正确 | ✅ | 拦截 `home_widget` 平台通道，验证 spec §4.3 全部 6 个 key 写入；`widget_items` 为 JSON 数组（≤3 条）；金额含 `¥` |
| Deep Link `lifeitems://` URI 路由重定向逻辑 | ✅ | `lifeitems://smart-entry/input → /smart-entry/input`、`lifeitems://bills/new → /bills/new`、`lifeitems://items → /items`；非 scheme 路径不重定向 |

### 关键验证点
- **Widget 数据格式**：`widget_date`/`widget_today_count`/`widget_overdue_count`/`widget_items`/`widget_monthly_income`/`widget_monthly_expense` 全部正确写入。
- **静态注册完备**：`AndroidManifest.xml` 已注册 App Shortcuts（`shortcuts.xml`）、Deep Link intent-filter（`lifeitems` scheme）、Widget Provider（`HomeWidgetProvider`）、系统分享接收器（SEND text/plain）。
- **静态降级**：`syncFromRef/syncFromProviders` 内部 `try/catch` 静默失败，不阻断 App。

> **未覆盖**：真实把 Widget 拖到桌面、长按图标快捷菜单、从微信分享进来——需真机手动操作。

## 4. 阶段三：智能洞察与自动化（Insights）✅

### 集成测试（2/2 通过）

| 测试 | 结果 | 说明 |
|------|------|------|
| 统计页趋势图表（每日支出 / 分类趋势）在有数据时渲染 | ✅ | 注入当月带分类的账单后，统计页出现「本月每日支出」「分类消费趋势」「近6个月趋势」三个图表卡片，无「暂无数据」空态 |
| 自动分类推荐 chip：账单编辑页输入历史标题后出现并可采纳 | ✅ | 先落库一条带分类的「午餐」账单，新建账单输入「午餐」→ 500ms debounce 后出现「推荐：xxx」chip → 点击采纳后 chip 消失 |

### 关键验证点
- **三张趋势图**（`fl_chart`）：每日柱状图（超日均 1.5× 标红）、分类堆叠柱状图、6 个月趋势。
- **自动分类算法**：`suggestCategoryByTitle` 按历史标题 LIKE 匹配 + 频率排序，返回使用最多的 `category_id`。
- **非侵入式推荐**：chip 仅在用户未手动选分类时出现，点击即采纳。

### 截图（`screenshots/phase_screenshots/`）
- `p3_statistics_trend.png` — 统计页趋势图表（每日支出柱状图）
- `p3_category_trend_chart.png` — 分类消费趋势堆叠图
- `p3_category_suggestion_chip.png` — 账单编辑页「推荐：xxx」chip

## 5. 发现的问题与说明

### 5.1 Release 构建 R8 失败（非三阶段功能问题）
- **现象**：`flutter run --release` 在 `minifyReleaseWithR8` 阶段失败，缺失 ML Kit 中文/日文/韩文等 `TextRecognizerOptions` 类。
- **原因**：`google_mlkit_text_recognition` 引用了未随包打包的脚本识别器类，R8 收缩时找不到。
- **影响**：仅影响 Release 构建；Debug 构建与三阶段功能完全正常。
- **建议修复**：在 `android/app/proguard-rules.pro` 加入自动生成的 `-dontwarn` 规则（见 `build/app/outputs/mapping/release/missing_rules.txt`）。
- **本次测试**：全部用 Debug 模式验证，结论不受影响。

### 5.2 三阶段功能：未发现缺陷
所有可程序化驱动的功能路径均通过；OCR/语音/系统分享/真实桌面 Widget 等依赖外部环境的能力未在本次覆盖，需后续真机手动验证。

## 6. 测试产物

| 文件 | 说明 |
|------|------|
| `integration_test/three_phases_integration_test.dart` | 三阶段功能集成测试（7 用例全过） |
| `integration_test/screenshot_each_phase_test.dart` | 三阶段可视化截图测试（8 张） |
| `screenshots/phase_screenshots/*.png` | 8 张阶段截图证据 |
| `lib/core/router/app_router.dart` | 重构：抽取 `createAppRouter()` 工厂，便于测试隔离路由实例（生产 `appRouter` 不变） |

## 7. 复现步骤

```bash
# 功能集成测试（需连接模拟器/设备）
flutter test integration_test/three_phases_integration_test.dart -d emulator-5554

# 截图测试（截图落在设备 App 外部目录，需 adb pull 取回）
flutter test integration_test/screenshot_each_phase_test.dart -d emulator-5554
adb -s emulator-5554 pull \
  /storage/emulated/0/Android/data/com.lifeitems.record_everything/files/phase_screenshots \
  screenshots/phase_screenshots
```

## 8. 结论

**三阶段功能在 Android 模拟器（API 36）上全部验证通过**：阶段一智能录入（3/3）、阶段二桌面与快捷触达（2/2）、阶段三智能洞察与自动化（2/2），集成测试 7/7 通过，配套 8 张截图佐证。唯一阻塞项为 Release 模式 ML Kit R8 收缩问题（与三阶段功能无关，建议补 ProGuard 规则修复）。

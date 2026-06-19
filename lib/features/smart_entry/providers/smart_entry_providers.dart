import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/daos/category_dao.dart';
import '../../../data/database/database_provider.dart';
import '../../bill/providers/bill_providers.dart';
import '../../life_item/providers/life_item_providers.dart';
import '../models/draft_item.dart';
import '../parser/cloud_parser.dart';
import '../parser/smart_entry_parser.dart';
import '../services/category_matcher.dart';
import '../services/secure_key_store.dart';

/// FutureProvider：首次读取时从 secure storage 加载 AiConfig，
/// 据此决定注入 NoopCloudParser 还是 QwenCloudParser。
final smartEntryParserProvider = FutureProvider<SmartEntryParser>((ref) async {
  final config = await ref.read(secureKeyStoreProvider).load();
  final cloud = config.enabled && config.isConfigured
      ? QwenCloudParser(
          apiKey: config.apiKey!,
          model: config.model ?? 'qwen-plus',
        )
      : const NoopCloudParser();
  return SmartEntryParser(cloud: cloud);
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
/// 事项走 lifeItemNotifierProvider.create(Map)（含提醒调度），
/// 账单走 billNotifierProvider.create(named)（内部确保默认账户，对齐 BillEditPage）。
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
            await matcher.matchId(
              item.categoryGuess,
              item.kind,
              item.amountType,
            );

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
          // BillNotifier.create 用命名参数，内部解析默认账户，对齐 BillEditPage 链路。
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

final smartEntryPersistProvider = Provider<SmartEntryPersistService>((ref) {
  return SmartEntryPersistService(ref);
});

/// 根据账单标题推荐分类 id（基于历史账单匹配频率）。
final categorySuggestionProvider =
    FutureProvider.family<int?, (String title, String amountType)>(
  (ref, params) async {
    final (title, amountType) = params;
    final db = ref.read(databaseProvider);
    return db.billRecordDao.suggestCategoryByTitle(title, amountType);
  },
);

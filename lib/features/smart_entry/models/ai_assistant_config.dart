import 'draft_item.dart';

class AiProviderIds {
  const AiProviderIds._();

  static const zhipu = 'zhipu';
  static const deepSeek = 'deepseek';
  static const openAiCompatible = 'openai_compatible';
  static const qwen = 'qwen';
}

class AiProfileTemplate {
  const AiProfileTemplate({
    required this.providerId,
    required this.name,
    required this.baseUrl,
    required this.model,
  });

  final String providerId;
  final String name;
  final String baseUrl;
  final String model;

  static const zhipu = AiProfileTemplate(
    providerId: AiProviderIds.zhipu,
    name: '智谱',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    model: 'glm-4-flash',
  );

  static const deepSeek = AiProfileTemplate(
    providerId: AiProviderIds.deepSeek,
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-chat',
  );

  static const openAiCompatible = AiProfileTemplate(
    providerId: AiProviderIds.openAiCompatible,
    name: 'OpenAI 兼容',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4.1-mini',
  );

  static const builtInDefaults = [zhipu, deepSeek];

  static AiProfileTemplate byProviderId(String? providerId) {
    return switch (providerId) {
      AiProviderIds.deepSeek => deepSeek,
      AiProviderIds.openAiCompatible => openAiCompatible,
      _ => zhipu,
    };
  }

  AiAssistantProfile createProfile({
    required String id,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
  }) {
    return AiAssistantProfile(
      id: id,
      providerId: providerId,
      name: name?.trim().isNotEmpty == true ? name!.trim() : this.name,
      apiKey: apiKey?.trim() ?? '',
      baseUrl: AiAssistantProfile.normalizeBaseUrl(baseUrl ?? this.baseUrl),
      model: model?.trim().isNotEmpty == true ? model!.trim() : this.model,
    );
  }
}

class AiAssistantProfile {
  const AiAssistantProfile({
    required this.id,
    required this.providerId,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  final String id;
  final String providerId;
  final String name;
  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  Uri get chatCompletionsUri {
    return Uri.parse('${normalizeBaseUrl(baseUrl)}/chat/completions');
  }

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  AiAssistantProfile copyWith({
    String? id,
    String? providerId,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
  }) {
    return AiAssistantProfile(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl == null ? this.baseUrl : normalizeBaseUrl(baseUrl),
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'name': name,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
    };
  }

  factory AiAssistantProfile.fromJson(Map<String, dynamic> json) {
    final providerId = json['providerId'] as String? ?? AiProviderIds.zhipu;
    final template = AiProfileTemplate.byProviderId(providerId);
    return template.createProfile(
      id: json['id'] as String? ?? providerId,
      name: json['name'] as String?,
      apiKey: json['apiKey'] as String?,
      baseUrl: json['baseUrl'] as String?,
      model: json['model'] as String?,
    );
  }
}

class LocalSmartEntryRule {
  const LocalSmartEntryRule({
    required this.id,
    required this.name,
    required this.keywords,
    this.enabled = true,
    this.priority = 0,
    this.kind,
    this.categoryGuess,
    this.amountType,
  });

  final String id;
  final String name;
  final List<String> keywords;
  final bool enabled;
  final int priority;
  final DraftKind? kind;
  final String? categoryGuess;
  final DraftAmountType? amountType;

  bool matches(String text) {
    if (!enabled) return false;
    return keywords.any((keyword) {
      final value = keyword.trim();
      return value.isNotEmpty && text.contains(value);
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'keywords': keywords,
      'enabled': enabled,
      'priority': priority,
      'kind': kind?.name,
      'categoryGuess': categoryGuess,
      'amountType': amountType?.value,
    };
  }

  factory LocalSmartEntryRule.fromJson(Map<String, dynamic> json) {
    return LocalSmartEntryRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      keywords: (json['keywords'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
      kind: _kindFromString(json['kind'] as String?),
      categoryGuess: json['categoryGuess'] as String?,
      amountType: json['amountType'] == null
          ? null
          : DraftAmountTypeX.fromString(json['amountType'] as String),
    );
  }

  static DraftKind? _kindFromString(String? value) {
    return switch (value) {
      'bill' => DraftKind.bill,
      'lifeItem' => DraftKind.lifeItem,
      _ => null,
    };
  }
}

class AiAssistantConfig {
  const AiAssistantConfig({
    required this.enabled,
    required this.alwaysCloud,
    required this.activeProfileId,
    required this.profiles,
    this.localRules = const [],
  });

  final bool enabled;
  final bool alwaysCloud;
  final String activeProfileId;
  final List<AiAssistantProfile> profiles;
  final List<LocalSmartEntryRule> localRules;

  factory AiAssistantConfig.defaults() {
    final profiles = [
      AiProfileTemplate.zhipu.createProfile(id: AiProviderIds.zhipu),
      AiProfileTemplate.deepSeek.createProfile(id: AiProviderIds.deepSeek),
    ];
    return AiAssistantConfig(
      enabled: false,
      alwaysCloud: false,
      activeProfileId: profiles.first.id,
      profiles: profiles,
    );
  }

  AiAssistantProfile get activeProfile {
    return profiles.firstWhere(
      (profile) => profile.id == activeProfileId,
      orElse: () => profiles.isEmpty
          ? AiProfileTemplate.zhipu.createProfile(id: AiProviderIds.zhipu)
          : profiles.first,
    );
  }

  bool get isConfigured => enabled && activeProfile.isConfigured;

  AiAssistantConfig copyWith({
    bool? enabled,
    bool? alwaysCloud,
    String? activeProfileId,
    List<AiAssistantProfile>? profiles,
    List<LocalSmartEntryRule>? localRules,
  }) {
    return AiAssistantConfig(
      enabled: enabled ?? this.enabled,
      alwaysCloud: alwaysCloud ?? this.alwaysCloud,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profiles: profiles ?? this.profiles,
      localRules: localRules ?? this.localRules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 2,
      'enabled': enabled,
      'alwaysCloud': alwaysCloud,
      'activeProfileId': activeProfileId,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'localRules': localRules.map((rule) => rule.toJson()).toList(),
    };
  }

  factory AiAssistantConfig.fromJson(Map<String, dynamic> json) {
    final profiles = (json['profiles'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AiAssistantProfile.fromJson)
        .toList();
    final defaults = AiAssistantConfig.defaults();
    final mergedProfiles = profiles.isEmpty ? defaults.profiles : profiles;
    return AiAssistantConfig(
      enabled: json['enabled'] as bool? ?? false,
      alwaysCloud: json['alwaysCloud'] as bool? ?? false,
      activeProfileId:
          json['activeProfileId'] as String? ?? mergedProfiles.first.id,
      profiles: mergedProfiles,
      localRules: (json['localRules'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LocalSmartEntryRule.fromJson)
          .toList(),
    );
  }

  factory AiAssistantConfig.fromLegacy({
    required String? provider,
    required String? apiKey,
    required String? model,
    required bool enabled,
    required bool alwaysCloud,
  }) {
    final defaults = AiAssistantConfig.defaults();
    final providerId = _normalizeLegacyProvider(provider);
    final migratedProfiles = defaults.profiles.map((profile) {
      if (profile.providerId != providerId) return profile;
      return profile.copyWith(apiKey: apiKey ?? '', model: model);
    }).toList();
    return defaults.copyWith(
      enabled: enabled,
      alwaysCloud: alwaysCloud,
      activeProfileId: providerId,
      profiles: migratedProfiles,
    );
  }

  static String _normalizeLegacyProvider(String? provider) {
    return switch (provider) {
      AiProviderIds.deepSeek || 'deepSeek' => AiProviderIds.deepSeek,
      _ => AiProviderIds.zhipu,
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/l10n/l10n.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast.dart';
import '../models/ai_assistant_config.dart';
import '../models/draft_item.dart';
import '../providers/smart_entry_providers.dart';
import '../services/secure_key_store.dart';

/// BYOK AI 助手设置页。spec §8.1。
class AiAssistantSettingsPage extends ConsumerStatefulWidget {
  const AiAssistantSettingsPage({super.key});

  @override
  ConsumerState<AiAssistantSettingsPage> createState() =>
      _AiAssistantSettingsPageState();
}

class _AiAssistantSettingsPageState
    extends ConsumerState<AiAssistantSettingsPage> {
  final _profileNameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  AiAssistantConfig _config = AiAssistantConfig.defaults();
  bool _loading = true;
  bool _saving = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await ref.read(secureKeyStoreProvider).loadConfig();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
      _syncControllers(config.activeProfile);
    });
  }

  void _syncControllers(AiAssistantProfile profile) {
    _profileNameController.text = profile.name;
    _baseUrlController.text = profile.baseUrl;
    _apiKeyController.text = profile.apiKey;
    _modelController.text = profile.model;
  }

  void _selectProfile(String? id) {
    if (id == null) return;
    final profile = _config.profiles.firstWhere((item) => item.id == id);
    setState(() {
      _config = _config.copyWith(activeProfileId: id);
      _syncControllers(profile);
    });
  }

  void _addOpenAiProfile() {
    final id = 'openai-${DateTime.now().microsecondsSinceEpoch}';
    final profile = AiProfileTemplate.openAiCompatible.createProfile(
      id: id,
      name: 'OpenAI 兼容',
      apiKey: '',
    );
    setState(() {
      _config = _config.copyWith(
        enabled: true,
        activeProfileId: id,
        profiles: [..._config.profiles, profile],
      );
      _syncControllers(profile);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final active = _config.activeProfile.copyWith(
        name: _profileNameController.text.trim().isEmpty
            ? _config.activeProfile.name
            : _profileNameController.text.trim(),
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
      );
      final profiles = [
        for (final profile in _config.profiles)
          if (profile.id == active.id) active else profile,
      ];
      final next = _config.copyWith(profiles: profiles);
      await ref.read(secureKeyStoreProvider).saveConfig(next);
      ref.invalidate(smartEntryParserProvider);
      if (!mounted) return;
      setState(() => _config = next);
      Toast.success(context, context.l.toast_saved);
    } catch (e) {
      if (mounted) Toast.error(context, '保存失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addRule() async {
    final rule = await showDialog<LocalSmartEntryRule>(
      context: context,
      builder: (context) => const _RuleDialog(),
    );
    if (rule == null) return;
    setState(() {
      _config = _config.copyWith(localRules: [..._config.localRules, rule]);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l.page_aiAssistant)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _section(
            children: [
              SwitchListTile(
                title: const Text('启用智能输入'),
                subtitle: const Text('关闭后所有解析走本地规则引擎'),
                value: _config.enabled,
                onChanged: (value) {
                  setState(() => _config = _config.copyWith(enabled: value));
                },
              ),
              SwitchListTile(
                title: const Text('始终使用云端'),
                subtitle: const Text('关闭时仅本地解析不出或低置信时才走云端'),
                value: _config.alwaysCloud,
                onChanged: (value) {
                  setState(
                    () => _config = _config.copyWith(alwaysCloud: value),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _section(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '当前配置',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('ai-add-openai-profile'),
                    onPressed: _addOpenAiProfile,
                    icon: const Icon(Icons.add),
                    label: const Text('OpenAI 兼容'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('ai-profile-selector'),
                initialValue: _config.activeProfile.id,
                decoration: _inputDecoration(context, '当前配置'),
                items: [
                  for (final profile in _config.profiles)
                    DropdownMenuItem(
                      value: profile.id,
                      child: Text(profile.name),
                    ),
                ],
                onChanged: _selectProfile,
              ),
              const SizedBox(height: 12),
              _textField(
                key: const ValueKey('ai-profile-name-field'),
                controller: _profileNameController,
                label: '配置名称',
              ),
              const SizedBox(height: 12),
              _textField(
                key: const ValueKey('ai-base-url-field'),
                controller: _baseUrlController,
                label: 'Base URL',
                hint: 'https://api.example.com/v1',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              _textField(
                key: const ValueKey('ai-model-field'),
                controller: _modelController,
                label: '模型',
                hint: 'deepseek-chat / glm-4-flash / custom-model',
              ),
              const SizedBox(height: 12),
              _textField(
                key: const ValueKey('ai-api-key-field'),
                controller: _apiKeyController,
                label: 'API Key',
                hint: 'sk-...',
                obscureText: _obscureApiKey,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _section(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '本地规则',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add),
                    label: const Text('新增规则'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_config.localRules.isEmpty)
                Text(
                  '未添加自定义规则，当前使用内置关键词和云端兜底。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                )
              else
                for (final rule in _config.localRules)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(rule.name),
                    subtitle: Text(rule.keywords.join(' / ')),
                    trailing: Text(rule.categoryGuess ?? '-'),
                  ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('ai-save-btn'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中...' : '保存'),
          ),
          const SizedBox(height: 8),
          Text(
            'API Key 存储在设备安全存储中，不会包含在备份导出中。内置供应商只提供填写模板，可复制后改为自己的兼容服务。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required List<Widget> children,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Material(
      color: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: _inputDecoration(
        context,
        label,
        hint: hint,
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: AppColors.surface(context),
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog();

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _nameController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _categoryController = TextEditingController();
  DraftKind _kind = DraftKind.bill;

  @override
  void dispose() {
    _nameController.dispose();
    _keywordsController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增规则'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          TextField(
            controller: _keywordsController,
            decoration: const InputDecoration(labelText: '关键词，用逗号分隔'),
          ),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: '分类猜测'),
          ),
          DropdownButton<DraftKind>(
            value: _kind,
            items: const [
              DropdownMenuItem(value: DraftKind.bill, child: Text('账单')),
              DropdownMenuItem(value: DraftKind.lifeItem, child: Text('事项')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _kind = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final keywords = _keywordsController.text
                .split(RegExp(r'[,，]'))
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList();
            if (keywords.isEmpty) return;
            Navigator.of(context).pop(
              LocalSmartEntryRule(
                id: 'rule-${DateTime.now().microsecondsSinceEpoch}',
                name: _nameController.text.trim().isEmpty
                    ? keywords.first
                    : _nameController.text.trim(),
                keywords: keywords,
                priority: 10,
                kind: _kind,
                categoryGuess: _categoryController.text.trim().isEmpty
                    ? null
                    : _categoryController.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

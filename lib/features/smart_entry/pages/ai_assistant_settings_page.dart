import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
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
    if (!mounted) return;
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
    // 刷新 parser provider 使新配置生效。
    ref.invalidate(smartEntryParserProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用智能输入'),
            subtitle: const Text('关闭后所有解析走本地规则引擎'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const Divider(),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                hintText: 'sk-...',
              ),
              obscureText: true,
              controller: TextEditingController(text: _apiKey)
                ..selection = TextSelection.collapsed(offset: _apiKey.length),
              onChanged: (v) => _apiKey = v,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '模型',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _model)
                ..selection = TextSelection.collapsed(offset: _model.length),
              onChanged: (v) => _model = v,
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('始终使用云端'),
            subtitle: const Text('关闭时仅本地解析不出时才走云'),
            value: _alwaysCloud,
            onChanged: (v) => setState(() => _alwaysCloud = v),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
              onPressed: _save,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '说明：API Key 存储在设备安全存储中，不会上传到任何服务器，也不会包含在备份导出中。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

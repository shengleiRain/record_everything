import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record_everything/l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/toast.dart';
import '../models/webdav_config.dart';
import '../providers/settings_providers.dart';

class WebDavSettingsPage extends ConsumerStatefulWidget {
  const WebDavSettingsPage({super.key});

  @override
  ConsumerState<WebDavSettingsPage> createState() => _WebDavSettingsPageState();
}

class _WebDavSettingsPageState extends ConsumerState<WebDavSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController(text: '/backups/life-items/');
  bool _isLoading = false;
  bool _isTesting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final config = await ref.read(webdavConfigProvider.future);
    if (config != null && mounted) {
      _serverController.text = config.serverUrl;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _pathController.text = config.remotePath;
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l.page_webdavConfig)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildTextField(
              controller: _serverController,
              label: '服务器地址',
              hint: 'https://dav.example.com',
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入服务器地址';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return '请输入有效的 URL';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _usernameController,
              label: '用户名',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入用户名' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _passwordController,
              label: '密码',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? '请输入密码' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _pathController,
              label: '远程路径',
              hint: '/backups/life-items/',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find),
              label: Text(_isTesting ? '测试中...' : '测试连接'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Text('保存配置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: AppColors.surface(context),
      ),
      validator: validator,
    );
  }

  WebDavConfig _buildConfig() => WebDavConfig(
        serverUrl: _serverController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        remotePath: _pathController.text.trim().isEmpty
            ? '/backups/life-items/'
            : _pathController.text.trim(),
      );

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isTesting = true);
    try {
      final config = _buildConfig();
      await ref.read(settingsNotifierProvider.notifier).saveWebDavConfig(config);
      final ok = await ref
          .read(settingsNotifierProvider.notifier)
          .testWebDavConnection();
      if (mounted) {
        Toast.success(context, ok ? context.l.toast_connectionSuccess : context.l.toast_connectionFailed);
      }
    } catch (e) {
      if (mounted) Toast.error(context, '连接失败: $e');
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final config = _buildConfig();
      await ref.read(settingsNotifierProvider.notifier).saveWebDavConfig(config);
      if (mounted) {
        Toast.success(context, context.l.toast_configSaved);
        context.pop();
      }
    } catch (e) {
      if (mounted) Toast.error(context, '保存失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

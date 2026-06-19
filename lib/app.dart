import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/smart_entry/models/draft_item.dart';
import 'features/smart_entry/providers/smart_entry_providers.dart';
import 'features/smart_entry/services/share_receiver.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '生活事项',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: appRouter,
      builder: (context, child) => _ShareBootstrap(child: child!),
    );
  }
}

/// 在 GoRouter context 内拦截系统分享：冷启动读初始文本 + 热启动监听 stream。
/// 规格 §6.3。Dart 层完全平台无关，平台差异由 ShareReceiver 实现处理。
class _ShareBootstrap extends StatefulWidget {
  const _ShareBootstrap({required this.child});
  final Widget child;

  @override
  State<_ShareBootstrap> createState() => _ShareBootstrapState();
}

class _ShareBootstrapState extends State<_ShareBootstrap> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    final receiver = container.read(shareReceiverProvider);

    // 冷启动：读取初始分享文本。
    final initial = await receiver.getInitialSharedText;
    if (initial != null && initial.isNotEmpty && mounted) {
      await _openConfirm(initial);
    }

    // 热启动：监听后续分享。
    _sub = receiver.sharedTextStream.listen((text) async {
      if (text.isNotEmpty && mounted) {
        await _openConfirm(text);
      }
    });
  }

  Future<void> _openConfirm(String text) async {
    final container = ProviderScope.containerOf(context);
    final parser = container.read(smartEntryParserProvider);
    final draft = await parser.parse(text, source: DraftSource.share);
    if (!mounted) return;
    context.push('/smart-entry/confirm', extra: draft);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

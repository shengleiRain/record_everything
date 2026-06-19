import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 快速输入页。spec §6.1。
/// 切片3 将补全完整输入与解析逻辑；当前为占位骨架以便路由先编译通过。
class SmartEntryInputPage extends ConsumerStatefulWidget {
  const SmartEntryInputPage({super.key});

  @override
  ConsumerState<SmartEntryInputPage> createState() =>
      _SmartEntryInputPageState();
}

class _SmartEntryInputPageState extends ConsumerState<SmartEntryInputPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智能输入')),
      body: const Center(child: Text('即将上线')),
    );
  }
}

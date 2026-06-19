import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// 平台无关的分享接收抽象。spec §14.2。
abstract class ShareReceiver {
  Future<String?> get getInitialSharedText; // 冷启动
  Stream<String> get sharedTextStream; // 热启动
}

/// Android 实现：基于 receive_sharing_intent v1.8+。
/// 纯文本以 SharedMediaFile(path: text, type: .text) 形式到达。
class AndroidShareReceiver implements ShareReceiver {
  @override
  Future<String?> get getInitialSharedText async {
    final files = await ReceiveSharingIntent.instance.getInitialMedia();
    final textFile = files.cast<SharedMediaFile?>().firstWhere(
      (f) => f?.type == SharedMediaType.text,
      orElse: () => null,
    );
    if (textFile != null) {
      await ReceiveSharingIntent.instance.reset();
      return textFile.path;
    }
    return null;
  }

  @override
  Stream<String> get sharedTextStream {
    return ReceiveSharingIntent.instance.getMediaStream().map((files) {
      final textFile = files.cast<SharedMediaFile?>().firstWhere(
        (f) => f?.type == SharedMediaType.text,
        orElse: () => null,
      );
      return textFile?.path ?? '';
    }).where((t) => t.isNotEmpty);
  }
}

/// 用于 iOS 未来启用前 / 测试的占位实现。
class NoopShareReceiver implements ShareReceiver {
  const NoopShareReceiver();

  @override
  Future<String?> get getInitialSharedText async => null;

  @override
  Stream<String> get sharedTextStream => const Stream.empty();
}

/// 按平台选择 ShareReceiver 实现。
final shareReceiverProvider = Provider<ShareReceiver>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidShareReceiver();
  }
  return const NoopShareReceiver();
});

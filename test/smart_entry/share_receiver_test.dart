import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/features/smart_entry/services/share_receiver.dart';

void main() {
  test('ShareReceiver 接口契约：冷启动初始文本 + 热启动 stream', () async {
    final receiver = _FakeShareReceiver(initial: '明天开会');
    expect(await receiver.getInitialSharedText, '明天开会');
    final captured = <String>[];
    receiver.sharedTextStream.listen(captured.add);
    receiver.simulateNew('午餐花了25');
    await Future.delayed(Duration.zero);
    expect(captured, ['午餐花了25']);
  });

  test('NoopShareReceiver 冷启动返回 null，stream 为空', () async {
    const noop = NoopShareReceiver();
    expect(await noop.getInitialSharedText, isNull);
    expect(noop.sharedTextStream, emitsDone);
  });
}

class _FakeShareReceiver implements ShareReceiver {
  _FakeShareReceiver({this.initial});

  final String? initial;
  final _controller = StreamController<String>.broadcast();

  @override
  Future<String?> get getInitialSharedText async => initial;

  @override
  Stream<String> get sharedTextStream => _controller.stream;

  void simulateNew(String t) => _controller.add(t);
}

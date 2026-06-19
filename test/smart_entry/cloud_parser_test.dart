import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:record_everything/features/smart_entry/models/draft_item.dart';
import 'package:record_everything/features/smart_entry/parser/cloud_parser.dart';

/// 将内层 JSON 字符串包装为 OpenAI chat completions 响应格式。
/// content 字段必须是 JSON 字符串（被引号包裹），而非嵌套对象。
String _wrapAsChatResponse(String innerJson) {
  final outer = <String, dynamic>{
    'choices': [
      {
        'message': {'content': innerJson},
      },
    ],
  };
  return jsonEncode(outer);
}

/// MockClient helper：返回预设 HTTP 响应。
MockClient _mockClient(String body, {int status = 200}) {
  return MockClient((request) async {
    return http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

void main() {
  test('解析云端返回的 JSON 为 DraftItem 列表', () async {
    const innerJson =
        '{"items":[{"kind":"bill","title":"午餐","amount_cents":2500,"amount_type":"expense","time":"2026-06-20T12:00:00","remind_time":null,"repeat_rule":null,"category_guess":"餐饮","confidence":0.9}]}';
    final parser = QwenCloudParser(
      apiKey: 'fake',
      model: 'qwen-plus',
      client: _mockClient(_wrapAsChatResponse(innerJson)),
    );

    final items = await parser.parse('午餐花了25', source: DraftSource.nl);
    expect(items, hasLength(1));
    expect(items.first.title, '午餐');
    expect(items.first.amountCents, 2500);
    expect(items.first.kind, DraftKind.bill);
    expect(items.first.categoryGuess, '餐饮');
  });

  test('解析事项（lifeItem）', () async {
    const innerJson =
        '{"items":[{"kind":"lifeItem","title":"开会","amount_cents":null,"amount_type":"none","time":"2026-06-20T15:00:00","remind_time":"2026-06-20T14:30:00","repeat_rule":null,"category_guess":"工作","confidence":0.85}]}';
    final parser = QwenCloudParser(
      apiKey: 'x',
      model: 'm',
      client: _mockClient(_wrapAsChatResponse(innerJson)),
    );

    final items = await parser.parse('明天3点开会', source: DraftSource.nl);
    expect(items, hasLength(1));
    expect(items.first.kind, DraftKind.lifeItem);
    expect(items.first.remindTime, isNotNull);
  });

  test('非法 JSON 返回空且不抛', () async {
    final parser = QwenCloudParser(
      apiKey: 'x',
      model: 'm',
      client: _mockClient('not json'),
    );
    final items = await parser.parse('任意', source: DraftSource.nl);
    expect(items, isEmpty);
  });

  test('HTTP 错误返回空且不抛', () async {
    final parser = QwenCloudParser(
      apiKey: 'x',
      model: 'm',
      client: _mockClient('', status: 500),
    );
    expect(await parser.parse('任意', source: DraftSource.nl), isEmpty);
  });

  test('NoopCloudParser 始终返回空', () async {
    const noop = NoopCloudParser();
    expect(await noop.parse('任意', source: DraftSource.nl), isEmpty);
  });
}

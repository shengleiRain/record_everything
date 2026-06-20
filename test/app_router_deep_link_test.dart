import 'package:flutter_test/flutter_test.dart';
import 'package:record_everything/core/router/app_router.dart';

void main() {
  group('lifeItemsDeepLinkPath', () {
    test('maps shortcut URIs without producing trailing slash routes', () {
      expect(
        lifeItemsDeepLinkPath(Uri.parse('lifeitems://smart-entry/input')),
        '/smart-entry/input',
      );
      expect(
        lifeItemsDeepLinkPath(Uri.parse('lifeitems://bills/new')),
        '/bills/new',
      );
      expect(lifeItemsDeepLinkPath(Uri.parse('lifeitems://items/')), '/items');
      expect(
        lifeItemsDeepLinkPath(Uri.parse('lifeitems://statistics/')),
        '/statistics',
      );
    });

    test('ignores non lifeitems schemes', () {
      expect(lifeItemsDeepLinkPath(Uri.parse('/home')), isNull);
      expect(lifeItemsDeepLinkPath(Uri.parse('https://example.com')), isNull);
    });
  });
}

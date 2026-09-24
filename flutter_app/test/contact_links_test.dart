import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/widgets/contact_links.dart';

void main() {
  testWidgets('phone, text, and map taps launch the correct destinations', (
    tester,
  ) async {
    final opened = <String>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            opened.add((call.arguments as Map)['url'] as String);
            return true;
          }
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ContactLink(kind: 'phone', text: '(310) 555-0123'),
              ContactLink(
                kind: 'address',
                text: '100 Main St, Los Angeles, CA',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('(310) 555-0123'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Text this number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 Main St, Los Angeles, CA'));
    await tester.pumpAndSettle();
    expect(opened.take(2), ['tel:3105550123', 'sms:3105550123']);
    expect(
      Uri.parse(opened.last).queryParameters['query'],
      '100 Main St, Los Angeles, CA',
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });
}

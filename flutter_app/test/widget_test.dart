import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/dashboard.dart';
import 'package:flutter_app/screens/records.dart';
import 'package:flutter_app/services/operations.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('navigation and overview fit at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      await tester.pumpWidget(LobosApp(home: Dashboard(store: Operations(db))));
      await tester.pumpAndSettle();
      expect(find.text('Keep the day moving.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final page in [
        'Dispatch',
        'Clients',
        'Invoices',
        'Expenses',
        'Overview',
      ]) {
        await tester.tap(find.text(page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('client add, edit and search preserve one record', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      LobosApp(
        home: Scaffold(
          body: RecordsPage(collection: 'clients', store: Operations(db)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add client'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Company name'),
      'Acme',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await db.collection('clients').get()).docs, hasLength(1));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Company name'),
      'Acme Hauling',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final rows = (await db.collection('clients').get()).docs;
    expect(rows, hasLength(1));
    expect(rows.single.data()['name'], 'Acme Hauling');
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    expect(
      find.text('No matching records. Try a different filter.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'admin opens dispatch and invoices a delivered load at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeFirebaseFirestore();
        await db.collection('clients').doc('client').set({'name': 'Customer'});
        await db.collection('loads').doc('delivery').set({
          'clientId': 'client',
          'clientName': 'Customer',
          'status': 'delivered',
          'loadNumber': 'LD-TEST',
          'pickupAddress': 'Yard',
          'deliveryAddress': 'Site',
          'assignedDriverId': 'driver',
          'assignedDriverName': 'Driver',
          'updatedAt': Timestamp.now(),
        });
        const admin = AppUser(
          uid: 'admin',
          displayName: 'Admin',
          email: 'admin@example.com',
          active: true,
          permissions: UserPermissions(
            manageUsers: true,
            manageClients: true,
            manageLoads: true,
            viewAllLoads: true,
            updateAssignedLoads: true,
          ),
        );
        await tester.pumpWidget(
          LobosApp(
            home: Dashboard(store: Operations(db), user: admin),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ready to invoice'), findsOneWidget);
        expect(find.text('Standalone billing jobs'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Create invoice'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '125.50');
        await tester.tap(find.widgetWithText(FilledButton, 'Create invoice'));
        await tester.pumpAndSettle();
        expect(find.text('Invoice details'), findsOneWidget);
        expect((await db.collection('invoices').get()).docs, hasLength(1));
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Ready to invoice'), findsNothing);
        expect(find.text('View invoice'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
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

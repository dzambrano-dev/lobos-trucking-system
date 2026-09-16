import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/app_user.dart';
import 'package:flutter_app/screens/driver/driver_loads_page.dart';
import 'package:flutter_app/services/load_repository.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('driver accepts and reports an issue at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final ref = db.collection('loads').doc('trip');
      await ref.set({
        'status': 'assigned',
        'clientName': 'Test Customer',
        'loadNumber': 'LD-TEST',
        'assignedDriverId': 'driver',
        'assignedDriverName': 'Driver',
        'pickupAddress': 'Test Yard',
        'deliveryAddress': 'Test Site',
        'scheduledPickupAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      const user = AppUser(
        uid: 'driver',
        displayName: 'Driver',
        email: 'driver@example.com',
        active: true,
        permissions: UserPermissions(
          manageUsers: false,
          manageClients: false,
          manageLoads: false,
          viewAllLoads: false,
          updateAssignedLoads: true,
        ),
      );
      await tester.pumpWidget(
        LobosApp(
          home: DriverLoadsPage(
            user: user,
            repository: LoadRepository(firestore: db),
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accept assignment'), findsOneWidget);
      expect(find.text('Invoices'), findsNothing);
      await tester.tap(find.text('Accept assignment'));
      await tester.pumpAndSettle();
      expect((await ref.get()).data()!['status'], 'accepted');
      expect(find.text('I arrived at pickup'), findsOneWidget);
      await tester.tap(find.text('Report delay or problem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Waiting for dock');
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect((await ref.get()).data()!['needsAttention'], true);
      expect((await ref.collection('events').get()).docs, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_app/widgets/date_time_field.dart';
import 'package:flutter_app/services/load_repository.dart';
import 'package:flutter_app/models/load_record.dart';
import 'package:flutter_app/models/load_status.dart';
import 'package:flutter_app/models/app_user.dart';

void main() {
  testWidgets('delivery calendar and time selection can be set and cleared', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateTimeField(
            controller: controller,
            label: 'Planned delivery',
            seed: DateTime(2026, 9, 21, 14, 30),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.text, '2026-09-21 14:30');
    await tester.tap(find.byTooltip('Clear planned delivery'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
  });
  test(
    'office confirmation records actor and reason, rejects stale updates, keeps invoices intact',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = LoadRepository(firestore: db);
      const actor = AppUser(
        uid: 'admin',
        displayName: 'Admin',
        email: 'admin@example.com',
        active: true,
        permissions: UserPermissions(
          manageUsers: true,
          manageLoads: true,
          manageClients: true,
          viewAllLoads: true,
          updateAssignedLoads: true,
        ),
      );
      final ref = db.collection('loads').doc('l');
      await ref.set({'status': 'assigned'});
      final initial = LoadRecord.fromFirestore('l', (await ref.get()).data()!);
      await db.collection('invoices').doc('i').set({
        'amount': 250,
        'amountPaid': 100,
      });
      await expectLater(
        repo.correctStatus(
          load: initial,
          next: LoadProgressStatus.delivered,
          actor: actor,
          reason: ' ',
        ),
        throwsStateError,
      );
      await repo.correctStatus(
        load: initial,
        next: LoadProgressStatus.delivered,
        actor: actor,
        reason: 'Receiver called office',
      );
      final data = (await ref.get()).data()!;
      expect(data['status'], 'delivered');
      expect(data['officeDelivery']['confirmedBy'], 'admin');
      expect(data.containsKey('delivery'), false);
      expect(
        (await ref.collection('events').get()).docs.single.data()['note'],
        contains('Receiver called office'),
      );
      await expectLater(
        repo.correctStatus(
          load: initial,
          next: LoadProgressStatus.accepted,
          actor: actor,
          reason: 'Stale screen',
        ),
        throwsStateError,
      );
      expect((await db.collection('invoices').doc('i').get()).data(), {
        'amount': 250,
        'amountPaid': 100,
      });
    },
  );
}

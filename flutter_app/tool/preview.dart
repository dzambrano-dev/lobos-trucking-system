// Isolated, in-memory preview. This entry point never initializes Firebase.
// Run with: flutter run -d chrome -t tool/preview.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/dashboard.dart';
import 'package:flutter_app/services/operations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = FakeFirebaseFirestore();
  final now = DateTime.now();
  for (final (id, name) in [
    ('c1', 'Summit Building Supply'),
    ('c2', 'Westside Aggregates'),
    ('c3', 'Pacific Industrial'),
  ]) {
    await db.collection('clients').doc(id).set({
      'name': name,
      'contact': 'Sample contact',
      'phone': '(555) 010-2400',
      'email': 'dispatch@example.com',
      'address': 'Sample billing address',
      'createdAt': now,
    });
  }
  final jobs = [
    (
      'load-1042',
      'c1',
      'Summit Building Supply',
      'North yard',
      'Riverside job site',
      850.0,
      'in progress',
      'Alex Rivera',
      'Unit 04',
    ),
    (
      'load-1043',
      'c2',
      'Westside Aggregates',
      'West quarry',
      'Oak Street development',
      625.0,
      'pending',
      'Jordan Lee',
      'Unit 02',
    ),
    (
      'load-1044',
      'c3',
      'Pacific Industrial',
      'Port warehouse',
      'East distribution center',
      1200.0,
      'pending',
      'Sam Ortiz',
      'Unit 07',
    ),
    (
      'load-1041',
      'c1',
      'Summit Building Supply',
      'Main depot',
      'Central yard',
      975.0,
      'completed',
      'Alex Rivera',
      'Unit 04',
    ),
    (
      'load-1040',
      'c3',
      'Pacific Industrial',
      'Industrial park',
      'South warehouse',
      1850.0,
      'completed',
      'Sam Ortiz',
      'Unit 07',
    ),
  ];
  for (final j in jobs) {
    await db.collection('jobs').doc(j.$1).set({
      'clientId': j.$2,
      'clientName': j.$3,
      'pickup': j.$4,
      'dropoff': j.$5,
      'price': j.$6,
      'status': j.$7,
      'driver': j.$8,
      'truck': j.$9,
      'scheduledDate': now,
      'createdAt': now,
      'notes': 'Fictional preview record',
    });
  }
  final store = Operations(db);
  await store.saveCompany({
    'name': 'Lobos Trucking',
    'address': '123 Sample Road\nExample City, CA 90000',
    'email': 'billing@example.com',
    'paymentInstructions': 'Demo only — no payment should be sent.',
  });
  final invoice = await store.invoiceJob('load-1040');
  await store.recordPayment(
    invoice,
    500,
    'Sample check',
    paymentId: 'preview-payment',
  );
  await db.collection('invoices').doc(invoice).update({
    'dueDate': now.subtract(const Duration(days: 7)),
  });
  await store.save('expenses', {
    'category': 'Fuel',
    'amount': 285.40,
    'expenseDate': now,
    'vendor': 'Sample fuel stop',
  });
  runApp(
    LobosApp(
      home: Column(
        children: [
          const Material(
            color: Color(0xFFFFE6A6),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'DEMO · Fictional data · Changes reset when you reload',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: Dashboard(store: store)),
        ],
      ),
    ),
  );
}

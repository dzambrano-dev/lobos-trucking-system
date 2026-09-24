import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_app/services/operations.dart';
import 'package:flutter_app/screens/expense_accounts_page.dart';

void main() {
  testWidgets(
    'due reminders include old bills and export menu exposes four reports',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore(), now = DateTime.now();
      await db.collection('expenses').doc('old').set({
        'amount': 100,
        'amountPaid': 0,
        'paymentReviewed': true,
        'category': 'Fuel',
        'vendor': 'Old station',
        'expenseDate': DateTime(now.year, now.month - 1),
        'dueDate': now.subtract(const Duration(days: 2)),
      });
      await db.collection('invoices').doc('old').set({
        'amount': 200,
        'amountPaid': 0,
        'dueDate': now.subtract(const Duration(days: 2)),
      });
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseAccountsPage(
              store: Operations(db),
              onOpenInvoices: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      for (final text in [
        'Monthly summary',
        'Expenses and unpaid bills',
        'Invoices and balances',
        'Payment activity',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 overdue invoices'));
      expect(opened, isTrue);
      await tester.tap(find.text('1 bills overdue / due within 7 days'));
      await tester.pumpAndSettle();
      expect(find.text('Fuel · Old station'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

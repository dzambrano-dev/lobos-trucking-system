import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_app/services/expense_reports.dart';
import 'package:flutter_app/services/expense_accounts.dart';
import 'package:flutter_app/services/load_repository.dart';

void main() {
  test(
    'monthly reads retain balances and load full bill history on demand',
    () async {
      final db = FakeFirebaseFirestore();
      final reports = ExpenseReports(db);
      final month = DateTime(2026, 9);
      await ExpenseAccounts(db).save({
        'amount': 100,
        'category': 'Fuel',
        'expenseDate': month,
      }, id: 'bill');
      await ExpenseAccounts(db).pay('bill', {
        'amount': 10,
        'paidAt': DateTime(2026, 8),
        'reference': 'Old',
      }, 'old');
      await ExpenseAccounts(db).pay('bill', {
        'amount': 20,
        'paidAt': month,
        'reference': 'Current',
      }, 'current');
      await ExpenseAccounts(db).reverse('current', 'Correction');
      final result = await reports.load(month);
      expect(result['expense_payments']!.map((p) => p['id']), ['current']);
      expect(result['expense_reversals']!.map((p) => p['id']), ['current']);
      expect(result['expenses']!.single['amountPaid'], 10);
      final history = await reports.history('bill');
      expect(history['payments'], hasLength(2));
      expect(history['reversals'], hasLength(1));
    },
  );
  test(
    'driver reads every active assignment but only ten closed loads',
    () async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < 30; i++) {
        await db.collection('loads').doc('$i').set({
          'assignedDriverId': 'driver',
          'status': i < 15 ? 'assigned' : 'delivered',
          'updatedAt': DateTime(2026, 9, i + 1),
        });
      }
      final rows = await LoadRepository(
        firestore: db,
      ).watchAssignedLoads('driver').first;
      expect(rows.where((r) => !r.isClosed), hasLength(15));
      expect(rows.where((r) => r.isClosed), hasLength(10));
      expect(rows.any((r) => r.id == '15'), isFalse);
    },
  );
}

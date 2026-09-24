import 'package:cloud_firestore/cloud_firestore.dart';
import 'operations.dart';

/// Reports use explicit server reads rather than permanent ledger listeners.
class ExpenseReports {
  ExpenseReports(this.db);
  final FirebaseFirestore db;
  static const source = GetOptions(source: Source.server);

  Future<List<Record>> read(Query<Map<String, dynamic>> query) async {
    final result = await query.get(source);
    final rows = result.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    rows.sort(
      (a, b) => (dateOf(b['createdAt']) ?? DateTime(1970)).compareTo(
        dateOf(a['createdAt']) ?? DateTime(1970),
      ),
    );
    return rows;
  }

  Future<List<Record>> reversals(
    String collection,
    List<Record> payments,
  ) async {
    final ids = payments.map((p) => p['id'] as String).toList();
    final result = <Record>[];
    for (var start = 0; start < ids.length; start += 30) {
      final end = (start + 30).clamp(0, ids.length);
      result.addAll(
        await read(
          db
              .collection(collection)
              .where(FieldPath.documentId, whereIn: ids.sublist(start, end)),
        ),
      );
    }
    return result;
  }

  Future<Map<String, List<Record>>> load(
    DateTime month, {
    Map<String, List<Record>>? balances,
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    Query<Map<String, dynamic>> period(String name, String date) => db
        .collection(name)
        .where(date, isGreaterThanOrEqualTo: start)
        .where(date, isLessThan: end);
    final rows = await Future.wait([
      balances != null
          ? Future.value(balances['expenses']!)
          : read(db.collection('expenses')),
      balances != null
          ? Future.value(balances['invoices']!)
          : read(db.collection('invoices')),
      read(period('expense_payments', 'paidAt')),
      read(period('payments', 'createdAt')),
    ]);
    final corrections = await Future.wait([
      reversals('expense_reversals', rows[2]),
      reversals('payment_reversals', rows[3]),
    ]);
    return {
      'expenses': rows[0],
      'invoices': rows[1],
      'expense_payments': rows[2],
      'payments': rows[3],
      'expense_reversals': corrections[0],
      'payment_reversals': corrections[1],
    };
  }

  Future<Map<String, List<Record>>> history(String expenseId) async {
    final payments = await read(
      db
          .collection('expense_payments')
          .where('expenseId', isEqualTo: expenseId),
    );
    payments.sort(
      (a, b) => (dateOf(b['paidAt']) ?? DateTime(1970)).compareTo(
        dateOf(a['paidAt']) ?? DateTime(1970),
      ),
    );
    return {
      'payments': payments,
      'reversals': await reversals('expense_reversals', payments),
    };
  }
}

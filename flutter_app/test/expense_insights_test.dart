import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/widgets/expense_insights.dart';

void main() {
  test('category chart includes only selected month and preserves cents', () {
    final totals = expenseCategories([
      {
        'category': 'Fuel',
        'amount': 120.25,
        'expenseDate': DateTime(2026, 9, 1),
      },
      {
        'category': 'Fuel',
        'amount': 79.75,
        'expenseDate': DateTime(2026, 9, 2),
      },
      {'category': 'Tolls', 'amount': 50, 'expenseDate': DateTime(2026, 8, 2)},
    ], DateTime(2026, 9));
    expect(totals, {'Fuel': 20000});
  });
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('charts show a loss and fit at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpenseInsights(
                categories: const {'Fuel': 20000, 'Insurance': 10000},
                summary: const {
                  'incurred': 30000,
                  'profit': -10000,
                  'cashIn': 20000,
                  'cashOut': 15000,
                  'netCash': 5000,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Estimated operating loss'), findsOneWidget);
      expect(find.text('\$100.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty charts use neutral state without fictional data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExpenseInsights(
              categories: const {},
              summary: const {
                'incurred': 0,
                'profit': 0,
                'cashIn': 0,
                'cashOut': 0,
                'netCash': 0,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add an expense to see your breakdown.'), findsOneWidget);
    expect(find.text('Break-even'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

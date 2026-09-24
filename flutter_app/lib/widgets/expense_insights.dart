import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/operations.dart';

Map<String, int> expenseCategories(List<Record> bills, DateTime month) {
  final totals = <String, int>{};
  for (final bill in bills) {
    final date = dateOf(bill['expenseDate']);
    if (date == null || date.year != month.year || date.month != month.month) {
      continue;
    }
    final category = (bill['category'] ?? 'Other').toString();
    totals[category] = (totals[category] ?? 0) + cents(bill['amount']);
  }
  return totals;
}

class ExpenseMetric extends StatelessWidget {
  const ExpenseMetric({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.emphasis = false,
  });
  final String label, value;
  final String? detail;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: emphasis ? const Color(0xFF163F38) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3E8E3)),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(
        color: emphasis ? Colors.white : const Color(0xFF213C37),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    ),
  );
}

class ExpenseInsights extends StatelessWidget {
  const ExpenseInsights({
    super.key,
    required this.categories,
    required this.summary,
  });
  final Map<String, int> categories, summary;
  static const colors = [
    Color(0xFF23796B),
    Color(0xFFE2A54A),
    Color(0xFF668BB0),
    Color(0xFFA48ABD),
    Color(0xFFCA7766),
    Color(0xFF73827F),
  ];
  Widget panel(String title, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final entries = categories.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (sum, e) => sum + e.value);
    final revenue = summary['profit']! + summary['incurred']!;
    final expense = summary['incurred']!;
    final profit = summary['profit']!;
    final maximum = math.max(revenue, expense);
    final allocation = panel(
      'Where the money goes',
      Column(
        children: [
          Semantics(
            label: total == 0
                ? 'No expenses recorded for this month'
                : 'Expense categories, total ${money(total / 100)}. Breakdown listed below.',
            child: SizedBox(
              height: 180,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _Donut(
                        entries.map((e) => e.value).toList(),
                        colors,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(35),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total expenses',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            money(total / 100),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            const Text('Add an expense to see your breakdown.'),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entries[i].key)),
                  const SizedBox(width: 8),
                  Text(
                    '${(entries[i].value / total * 100).toStringAsFixed(0)}%  ${money(entries[i].value / 100)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    Widget bar(String label, int value, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            children: [
              Text(label),
              Text(
                money(value / 100),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: maximum == 0 ? 0 : (value / maximum).clamp(0, 1),
              minHeight: 18,
              color: color,
              backgroundColor: const Color(0xFFF0F3F1),
            ),
          ),
        ],
      ),
    );
    final performance = panel(
      'Profit & loss',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected month · invoiced basis',
            style: TextStyle(fontSize: 12, color: Color(0xFF64746E)),
          ),
          const SizedBox(height: 20),
          bar('Invoiced revenue', revenue, colors[0]),
          bar('Expenses incurred', expense, colors[1]),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: profit < 0
                  ? const Color(0xFFFFEFEB)
                  : const Color(0xFFEAF5F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profit < 0
                      ? 'Estimated operating loss'
                      : profit > 0
                      ? 'Estimated operating profit'
                      : 'Break-even',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(
                    money(profit.abs() / 100),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: profit < 0 ? const Color(0xFFA44435) : colors[0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Revenue minus recorded expenses. Unpaid invoices count as revenue; this is not cash in the bank.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
    return Column(
      children: [
        LayoutBuilder(
          builder: (_, box) => box.maxWidth >= 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: allocation),
                    const SizedBox(width: 12),
                    Expanded(child: performance),
                  ],
                )
              : Column(
                  children: [
                    allocation,
                    const SizedBox(height: 8),
                    performance,
                  ],
                ),
        ),
        panel(
          'Cash movement',
          Column(
            children: [
              for (final metric in {
                'Customer receipts': 'cashIn',
                'Expense payments': 'cashOut',
                'Net cash flow': 'netCash',
              }.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(metric.key)),
                      Text(
                        money(summary[metric.value]! / 100),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Donut extends CustomPainter {
  _Donut(this.values, this.colors);
  final List<int> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = const Color(0xFFE9EEEB),
    );
    final total = values.fold(0, (a, b) => a + b);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        paint..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      !listEquals(colors, oldDelegate.colors);
}

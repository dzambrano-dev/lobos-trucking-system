class Expense {
  final String id;
  final String? jobId;
  final String category;
  final double amount;

  Expense({
    required this.id,
    this.jobId,
    required this.category,
    required this.amount,
  });
}
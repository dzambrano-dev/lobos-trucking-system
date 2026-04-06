import '../models/expense.dart';

class ExpenseService {
  final List<Expense> expenses;

  ExpenseService({required this.expenses});

  List<Expense> getAllExpenses() {
    return expenses;
  }

  void addExpense(Expense expense) {
    expenses.add(expense);
  }

  double getTotalExpenses() {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  List<Expense> getExpensesByJob(String jobId) {
    return expenses
        .where((expense) => expense.jobId == jobId)
        .toList();
  }

  List<Expense> getExpensesByCategory(String category) {
    return expenses
        .where(
          (expense) => expense.category.toLowerCase() == category.toLowerCase(),
        )
        .toList();
  }
}
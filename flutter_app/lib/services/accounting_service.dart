import '../models/expense.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import '../models/payment.dart';

class AccountingService {
  final List<Expense> expenses;
  final List<Invoice> invoices;
  final List<Job> jobs;
  final List<Payment> payments;

  AccountingService({
    required this.expenses,
    required this.invoices,
    required this.jobs,
    required this.payments,
  });

  double getTotalRevenue() {
    return jobs.fold(0.0, (sum, job) => sum + job.price);
  }

  double getTotalExpenses() {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double getNetProfit() {
    return getTotalRevenue() - getTotalExpenses();
  }

  double getOutstandingInvoices() {
    return invoices
        .where((invoice) => invoice.status.toLowerCase() != 'paid')
        .fold(0.0, (sum, invoice) => sum + invoice.amount);
  }

  double getPaymentsReceived() {
    return payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  double getJobProfit(String jobId) {
    final job = jobs.firstWhere((j) => j.id == jobId);

    final relatedExpenses = expenses
        .where((expense) => expense.jobId == jobId)
        .fold(0.0, (sum, expense) => sum + expense.amount);

    return job.price - relatedExpenses;
  }
}
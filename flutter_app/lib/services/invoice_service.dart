import '../models/invoice.dart';

class InvoiceService {
  final List<Invoice> invoices;

  InvoiceService({required this.invoices});

  List<Invoice> getAllInvoices() {
    return invoices;
  }

  void addInvoice(Invoice invoice) {
    invoices.add(invoice);
  }

  List<Invoice> getPaidInvoices() {
    return invoices
        .where((invoice) => invoice.status.toLowerCase() == 'paid')
        .toList();
  }

  List<Invoice> getUnpaidInvoices() {
    return invoices
        .where((invoice) => invoice.status.toLowerCase() != 'paid')
        .toList();
  }

  double getTotalInvoiceAmount() {
    return invoices.fold(0.0, (sum, invoice) => sum + invoice.amount);
  }

  double getOutstandingBalance() {
    return invoices
        .where((invoice) => invoice.status.toLowerCase() != 'paid')
        .fold(0.0, (sum, invoice) => sum + invoice.amount);
  }
}
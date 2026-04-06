import '../models/payment.dart';

class PaymentService {
  final List<Payment> payments;

  PaymentService({required this.payments});

  List<Payment> getAllPayments() {
    return payments;
  }

  void addPayment(Payment payment) {
    payments.add(payment);
  }

  double getTotalPaymentsReceived() {
    return payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  List<Payment> getPaymentsByInvoice(String invoiceId) {
    return payments
        .where((payment) => payment.invoiceId == invoiceId)
        .toList();
  }
}
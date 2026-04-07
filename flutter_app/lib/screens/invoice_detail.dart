import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceDetailPage extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailPage({super.key, required this.invoice});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Job? job;
  bool isLoading = true;

  late Invoice invoice;

  @override
  void initState() {
    super.initState();
    invoice = widget.invoice;
    loadJob();
  }

  // ================= LOAD JOB =================
  Future<void> loadJob() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(invoice.jobId)
          .get();

      if (doc.exists) {
        job = Job.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }
    } catch (_) {}

    setState(() => isLoading = false);
  }

  // ================= UPDATE STATUS =================
  Future<void> updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('invoices')
        .doc(invoice.id)
        .update({"status": newStatus});

    setState(() {
      invoice = invoice.copyWith(status: newStatus);
    });
  }

  // ================= HELPERS =================
  String formatCurrency(double amount) {
    return "\$${amount.toStringAsFixed(2)}";
  }

  String formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "paid":
        return Colors.green;
      case "overdue":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // ================= PDF =================
  Future<void> generatePDF() async {
    if (job == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "LOBOS TRUCKING",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 10),

                pw.Text("Invoice #: ${invoice.invoiceNumber}"),
                pw.Text("Date: ${formatDate(invoice.createdAt)}"),

                pw.Divider(),

                pw.Text("Client: ${invoice.client}"),

                pw.SizedBox(height: 10),

                pw.Text("Route: ${job!.pickup} → ${job!.dropoff}"),

                pw.SizedBox(height: 10),

                pw.Text(
                  "Amount Due: ${formatCurrency(invoice.amount)}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),

                pw.Text("Status: ${invoice.status.toUpperCase()}"),

                if (invoice.notes != null && invoice.notes!.isNotEmpty)
                  pw.Text("Notes: ${invoice.notes}"),

                pw.SizedBox(height: 30),

                pw.Divider(),

                pw.Text("Thank you for your business."),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invoice Details")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : job == null
            ? const Center(child: Text("Job not found"))
            : Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= HEADER =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "INVOICE",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            invoice.invoiceNumber,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ================= STATUS BADGE =================
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: getStatusColor(invoice.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          invoice.status.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ================= CLIENT =================
                      const Text(
                        "Client",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(invoice.client),

                      const SizedBox(height: 20),

                      // ================= ROUTE =================
                      const Text(
                        "Route",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text("${job!.pickup} → ${job!.dropoff}"),

                      const SizedBox(height: 20),

                      // ================= AMOUNT =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Amount",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatCurrency(invoice.amount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ================= NOTES =================
                      if (invoice.notes != null && invoice.notes!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Notes",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(invoice.notes!),
                            const SizedBox(height: 20),
                          ],
                        ),

                      Text("Date: ${formatDate(invoice.createdAt)}"),

                      const SizedBox(height: 20),

                      const Divider(),

                      const SizedBox(height: 10),

                      const Text(
                        "Thank you for your business.",
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),

                      const SizedBox(height: 20),

                      // ================= ACTION BUTTONS =================
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => updateStatus("paid"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text("Mark Paid"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => updateStatus("overdue"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text("Mark Overdue"),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // ================= PDF BUTTON =================
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: generatePDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("Download / Print Invoice"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

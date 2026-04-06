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

  // ================= LOAD JOB =================
  Future<void> loadJob() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.invoice.jobId)
          .get();

      if (doc.exists) {
        job = Job.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      // silent fail (can log later)
    }

    setState(() => isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    loadJob();
  }

  // ================= HELPERS =================
  String formatCurrency(double amount) {
    return "\$${amount.toStringAsFixed(2)}";
  }

  String formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "completed":
        return Colors.green;
      case "in progress":
        return Colors.orange;
      case "pending":
        return Colors.grey;
      default:
        return Colors.blueGrey;
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
                // HEADER
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "LOBOS TRUCKING",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text("INVOICE"),
                  ],
                ),

                pw.SizedBox(height: 20),

                pw.Text("Invoice #: ${widget.invoice.id.substring(0, 6)}"),
                pw.Text("Date: ${formatDate(widget.invoice.createdAt)}"),

                pw.Divider(),

                pw.Text("Client: ${widget.invoice.client}"),

                pw.SizedBox(height: 10),

                pw.Text("Route: ${job!.pickup} → ${job!.dropoff}"),

                pw.SizedBox(height: 10),

                pw.Text(
                  "Amount Due: ${formatCurrency(widget.invoice.amount)}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),

                pw.SizedBox(height: 10),

                pw.Text("Status: ${job!.status}"),

                if (job!.notes != null && job!.notes!.isNotEmpty)
                  pw.Text("Notes: ${job!.notes}"),

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
                            "#${widget.invoice.id.substring(0, 6)}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ================= CLIENT =================
                      const Text(
                        "Client",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.invoice.client,
                        style: const TextStyle(fontSize: 16),
                      ),

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
                            formatCurrency(widget.invoice.amount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // ================= STATUS =================
                      Row(
                        children: [
                          const Text("Status: "),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor(job!.status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              job!.status.toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ================= NOTES =================
                      if (job!.notes != null && job!.notes!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Notes",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(job!.notes!),
                            const SizedBox(height: 20),
                          ],
                        ),

                      // ================= DATE =================
                      Text("Date: ${formatDate(widget.invoice.createdAt)}"),

                      const SizedBox(height: 20),

                      const Divider(),

                      const SizedBox(height: 10),

                      const Text(
                        "Thank you for your business.",
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),

                      const SizedBox(height: 20),

                      // ================= BUTTON =================
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

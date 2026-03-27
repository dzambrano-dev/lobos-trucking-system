// NEED CHRIS INPUT
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

  // ================= LOAD JOB FROM FIRESTORE =================
  Future<void> loadJob() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.invoice.jobId)
          .get();

      if (doc.exists) {
        setState(() {
          job = Job.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    loadJob();
  }

  // ================= STATUS COLOR =================
  Color getStatusColor(String status) {
    switch (status) {
      case "completed":
        return Colors.green;
      case "in progress":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ================= PDF =================
  Future<void> generatePDF() async {
    if (job == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "INVOICE",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Text("Client: ${widget.invoice.client}"),
              pw.Text("Route: ${job!.pickup} → ${job!.dropoff}"),
              pw.Text("Amount: \$${widget.invoice.amount}"),
              pw.Text("Status: ${job!.status}"),

              if (job!.notes != null && job!.notes!.isNotEmpty)
                pw.Text("Notes: ${job!.notes}"),

              pw.SizedBox(height: 10),

              pw.Text(
                "Date: ${widget.invoice.createdAt.toLocal().toString().split('.')[0]}",
              ),

              pw.SizedBox(height: 20),

              pw.Divider(),

              pw.Text("Thank you for your business."),
            ],
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
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "INVOICE",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        "Client: ${widget.invoice.client}",
                        style: const TextStyle(fontSize: 18),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "Route:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      Text("${job!.pickup} → ${job!.dropoff}"),

                      const SizedBox(height: 10),

                      Text(
                        "Amount: \$${widget.invoice.amount}",
                        style: const TextStyle(fontSize: 18),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          const Text("Status: "),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor(job!.status),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              job!.status,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (job!.notes != null && job!.notes!.isNotEmpty)
                        Text("Notes: ${job!.notes}"),

                      const SizedBox(height: 20),

                      Text(
                        "Date: ${widget.invoice.createdAt.toLocal().toString().split('.')[0]}",
                      ),

                      const SizedBox(height: 20),

                      const Divider(),

                      const SizedBox(height: 10),

                      const Text(
                        "Thank you for your business.",
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: generatePDF,
                          child: const Text("Download / Print Invoice"),
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

import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../models/job.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceDetailPage extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailPage({super.key, required this.invoice});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Future<void> generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
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

              if (job!.notes != null) pw.Text("Notes: ${job!.notes}"),

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

  Job? job;

  // ================= LOAD JOB =================
  Future<void> loadJob() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('jobs');

    if (jsonString != null) {
      final List decoded = jsonDecode(jsonString);
      final jobs = decoded.map((e) => Job.fromMap(e)).toList();

      final found = jobs.where((j) => j.id == widget.invoice.jobId);

      if (found.isNotEmpty) {
        setState(() {
          job = found.first;
        });
      }
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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invoice Details")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: job == null
            ? const Center(child: CircularProgressIndicator())
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

                      Text(
                        "Route:",
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

                      if (job!.notes != null) Text("Notes: ${job!.notes}"),

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

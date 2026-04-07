import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';
import 'invoice_detail.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  // ================= STATUS COLOR =================
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

  // ================= FORMAT DATE =================
  String formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invoices")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .orderBy('createdAt', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          // ================= LOADING =================
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ================= EMPTY =================
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No invoices yet", style: TextStyle(fontSize: 16)),
            );
          }

          // ================= PARSE =================
          final invoices = snapshot.data!.docs.map((doc) {
            return Invoice.fromFirestore(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }).toList();

          // ================= LIST =================
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),

                    // ================= TITLE =================
                    title: Text(
                      invoice.client,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    // ================= SUBTITLE =================
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),

                        // Invoice number
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Amount
                        Text(
                          "\$${invoice.amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Date
                        Text(
                          formatDate(invoice.createdAt),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),

                    // ================= STATUS BADGE =================
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: getStatusColor(invoice.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        invoice.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // ================= NAVIGATION =================
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailPage(invoice: invoice),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

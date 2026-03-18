import 'package:flutter/material.dart';
import '../models/invoice.dart';
import 'invoice_detail.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final List<Invoice> invoices = [];

  Future<void> loadInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('invoices');

    if (jsonString != null) {
      final List decoded = jsonDecode(jsonString);

      setState(() {
        invoices.clear();
        invoices.addAll(decoded.map((e) => Invoice.fromMap(e)).toList());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invoices")),

      body: invoices.isEmpty
          ? const Center(child: Text("No invoices yet"))
          : ListView.builder(
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];

                return Card(
                  child: ListTile(
                    title: Text(invoice.client),
                    subtitle: Text("\$${invoice.amount}"),

                    // 👉 NAVIGATE TO DETAIL
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailPage(invoice: invoice),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

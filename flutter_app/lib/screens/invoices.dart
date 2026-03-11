import 'package:flutter/material.dart';

// InvoicesPage represents the billing and payment tracking screen
class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invoices")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Invoice Management",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: implement invoice creation page
                },
                child: const Text("Create Invoice"),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Invoice List (coming soon)",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

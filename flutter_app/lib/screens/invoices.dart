import 'package:flutter/material.dart';

// InvoicesPage represents the billing and payment tracking screen
class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold provides the base layout for the page
    return Scaffold(
      // Top navigation bar
      appBar: AppBar(title: const Text("Invoices")),

      // Main page content
      body: Padding(
        padding: const EdgeInsets.all(30),

        // Column layout for stacking elements vertically
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            const Text(
              "Invoice Management",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // Button for generating new invoices
            ElevatedButton(
              onPressed: () {
                // TODO: implement invoice generation
              },
              child: const Text("Create Invoice"),
            ),

            const SizedBox(height: 30),

            // Placeholder where invoices will be listed later
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

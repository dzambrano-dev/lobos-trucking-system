import 'package:flutter/material.dart';

// ClientsPage represents the screen used to manage company clients
class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold provides the overall page structure (app bar + body)
    return Scaffold(
      // App bar at the top of the screen
      appBar: AppBar(title: const Text("Clients")),

      // Main content area of the page
      body: Padding(
        padding: const EdgeInsets.all(30),

        // Column organizes UI elements vertically
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            const Text(
              "Client Management",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // Button that will later open the "Add Client" form
            ElevatedButton(
              onPressed: () {
                // TODO: implement client creation form
              },
              child: const Text("Add Client"),
            ),

            const SizedBox(height: 30),

            // Placeholder for the list of clients
            const Text(
              "Client List (coming soon)",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

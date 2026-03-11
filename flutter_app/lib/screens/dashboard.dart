import 'package:flutter/material.dart';

// Import the other pages so we can navigate to them
import 'clients.dart';
import 'jobs.dart';
import 'invoices.dart';

// Main dashboard screen shown when the app starts
class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold provides the main page structure (app bar, body, drawer, etc.)
    return Scaffold(
      // Top navigation bar
      appBar: AppBar(title: const Text("Lobos Trucking System")),

      // Sidebar navigation menu
      drawer: Drawer(
        child: ListView(
          children: [
            // Drawer header at the top of the sidebar
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                "Lobos Trucking",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),

            // Navigation item for the dashboard (current page)
            ListTile(
              title: const Text("Dashboard"),
              onTap: () {
                Navigator.pop(context); // closes the drawer
              },
            ),

            // Navigation item that opens the Clients page
            ListTile(
              title: const Text("Clients"),
              onTap: () {
                // Push a new page onto the navigation stack
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientsPage()),
                );
              },
            ),

            // Navigation item that opens the Jobs page
            ListTile(
              title: const Text("Jobs"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JobsPage()),
                );
              },
            ),

            // Navigation item that opens the Invoices page
            ListTile(
              title: const Text("Invoices"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InvoicesPage()),
                );
              },
            ),
          ],
        ),
      ),

      // Main content area of the dashboard
      body: const Center(
        child: Text("Dashboard", style: TextStyle(fontSize: 30)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'clients.dart';
import 'jobs.dart';
import 'invoices.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lobos Trucking System")),

      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                "Lobos Trucking",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Dashboard"),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Clients"),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientsPage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text("Jobs"),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JobsPage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Invoices"),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InvoicesPage()),
                );
              },
            ),
          ],
        ),
      ),

      body: const Center(
        child: Text("Dashboard", style: TextStyle(fontSize: 30)),
      ),
    );
  }
}

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
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context),
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

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Dashboard cards grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,

              children: [
                DashboardCard(
                  title: "Clients",
                  value: "12",
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClientsPage()),
                    );
                  },
                ),

                DashboardCard(
                  title: "Jobs",
                  value: "34",
                  icon: Icons.local_shipping,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JobsPage()),
                    );
                  },
                ),

                DashboardCard(
                  title: "Invoices",
                  value: "18",
                  icon: Icons.receipt_long,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InvoicesPage()),
                    );
                  },
                ),

                const DashboardCard(
                  title: "Revenue",
                  value: "\$42k",
                  icon: Icons.attach_money,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 30),

            /// Recent Activity Section
            const Text(
              "Recent Activity",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              elevation: 3,
              child: Column(
                children: const [
                  ActivityItem(
                    icon: Icons.person_add,
                    text: "New client added: Acme Logistics",
                  ),

                  Divider(height: 1),

                  ActivityItem(
                    icon: Icons.receipt,
                    text: "Invoice created: #1045",
                  ),

                  Divider(height: 1),

                  ActivityItem(
                    icon: Icons.local_shipping,
                    text: "Job scheduled: LA → Phoenix",
                  ),

                  Divider(height: 1),

                  ActivityItem(
                    icon: Icons.attach_money,
                    text: "Payment received: \$1200",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),

      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                radius: 28,
                child: Icon(icon, size: 28, color: color),
              ),

              const SizedBox(width: 15),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const ActivityItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(text));
  }
}

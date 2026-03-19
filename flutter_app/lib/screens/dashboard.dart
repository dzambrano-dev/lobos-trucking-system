import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'clients.dart';
import 'jobs.dart';
import 'invoices.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  // ================= NAVIGATION =================
  void goTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ================= COUNT STREAM =================
  Stream<int> getCount(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ================= REVENUE =================
  Stream<double> getRevenue() {
    return FirebaseFirestore.instance.collection('invoices').snapshots().map((
      snap,
    ) {
      double total = 0;
      for (var doc in snap.docs) {
        final data = doc.data();
        total += (data['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    });
  }

  // ================= STREAM CARD =================
  Widget buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<dynamic> stream,
    required String Function(dynamic) formatter,
    VoidCallback? onTap,
  }) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.hasData ? formatter(snapshot.data) : "...";

        return DashboardCard(
          title: title,
          value: value,
          icon: icon,
          color: color,
          onTap: onTap,
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lobos Trucking")),

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
                goTo(context, const ClientsPage());
              },
            ),

            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text("Jobs"),
              onTap: () {
                Navigator.pop(context);
                goTo(context, const JobsPage());
              },
            ),

            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text("Invoices"),
              onTap: () {
                Navigator.pop(context);
                goTo(context, const InvoicesPage());
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
            // ================= STATS =================
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,

              children: [
                buildStatCard(
                  title: "Clients",
                  icon: Icons.people,
                  color: Colors.blue,
                  stream: getCount('clients'),
                  formatter: (v) => v.toString(),
                  onTap: () => goTo(context, const ClientsPage()),
                ),

                buildStatCard(
                  title: "Jobs",
                  icon: Icons.local_shipping,
                  color: Colors.green,
                  stream: getCount('jobs'),
                  formatter: (v) => v.toString(),
                  onTap: () => goTo(context, const JobsPage()),
                ),

                buildStatCard(
                  title: "Invoices",
                  icon: Icons.receipt_long,
                  color: Colors.orange,
                  stream: getCount('invoices'),
                  formatter: (v) => v.toString(),
                  onTap: () => goTo(context, const InvoicesPage()),
                ),

                buildStatCard(
                  title: "Revenue",
                  icon: Icons.attach_money,
                  color: Colors.purple,
                  stream: getRevenue(),
                  formatter: (v) => "\$${v.toStringAsFixed(0)}",
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ================= RECENT ACTIVITY =================
            const Text(
              "System Status",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Card(
              child: Column(
                children: const [
                  ActivityItem(
                    icon: Icons.cloud_done,
                    text: "Connected to Firebase",
                  ),
                  Divider(height: 1),
                  ActivityItem(
                    icon: Icons.sync,
                    text: "Live data updates enabled",
                  ),
                  Divider(height: 1),
                  ActivityItem(
                    icon: Icons.check_circle,
                    text: "System operational",
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

// ================= CARD =================
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
                  Text(title),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
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

// ================= ACTIVITY =================
class ActivityItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const ActivityItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(text));
  }
}

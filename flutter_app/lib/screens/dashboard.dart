import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lobos Trucking System")),

      body: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dashboard",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            ElevatedButton(onPressed: () {}, child: const Text("Add Client")),

            const SizedBox(height: 10),

            ElevatedButton(onPressed: () {}, child: const Text("Add Job")),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {},
              child: const Text("Create Invoice"),
            ),

            const SizedBox(height: 40),

            const Text("Recent Jobs", style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

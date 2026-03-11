import 'package:flutter/material.dart';

// JobsPage represents the screen where trucking jobs / loads are tracked
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold provides layout structure
    return Scaffold(
      // Top navigation bar
      appBar: AppBar(title: const Text("Jobs")),

      // Page content
      body: Padding(
        padding: const EdgeInsets.all(30),

        // Column stacks widgets vertically
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            const Text(
              "Job Management",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // Button for creating a new trucking job
            ElevatedButton(
              onPressed: () {
                // TODO: implement job creation form
              },
              child: const Text("Create Job"),
            ),

            const SizedBox(height: 30),

            // Placeholder area where job records will eventually appear
            const Text(
              "Job List (coming soon)",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

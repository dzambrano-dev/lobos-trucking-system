import 'package:flutter/material.dart';

// JobsPage represents the screen where trucking jobs / loads are tracked
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Jobs")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Job Management",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: implement job creation form
                },
                child: const Text("Create Job"),
              ),
            ),

            const SizedBox(height: 30),

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

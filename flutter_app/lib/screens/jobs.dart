import 'package:flutter/material.dart';
import '../models/job.dart';

// JobsPage = main screen for managing trucking jobs
class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  // Temporary storage for jobs (we’ll upgrade this later)
  final List<Job> jobs = [];

  // Opens popup form to create a job
  void openCreateJobDialog() {
    final TextEditingController clientController = TextEditingController();
    final TextEditingController pickupController = TextEditingController();
    final TextEditingController dropoffController = TextEditingController();
    final TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Create Job"),

          // Input fields
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(labelText: "Client"),
                ),
                TextField(
                  controller: pickupController,
                  decoration: const InputDecoration(
                    labelText: "Pickup Location",
                  ),
                ),
                TextField(
                  controller: dropoffController,
                  decoration: const InputDecoration(
                    labelText: "Dropoff Location",
                  ),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),

          // Buttons
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  jobs.add(
                    Job(
                      client: clientController.text,
                      pickup: pickupController.text,
                      dropoff: dropoffController.text,
                      price: double.tryParse(priceController.text) ?? 0,
                    ),
                  );
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Jobs")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Job Management",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // Create Job Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: openCreateJobDialog,
                child: const Text("Create Job"),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Jobs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // Job List
            Expanded(
              child: jobs.isEmpty
                  ? const Center(child: Text("No jobs yet"))
                  : ListView.builder(
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];

                        return Card(
                          child: ListTile(
                            title: Text(job.client),
                            subtitle: Text(
                              "${job.pickup} → ${job.dropoff}\n\$${job.price}",
                            ),

                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  jobs.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

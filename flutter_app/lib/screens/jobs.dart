import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  // ================= STATUS COLOR =================
  Color getStatusColor(String status) {
    switch (status) {
      case "completed":
        return Colors.green;
      case "in progress":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ================= CREATE JOB =================
  void openCreateJobDialog() {
    final clientController = TextEditingController();
    final pickupController = TextEditingController();
    final dropoffController = TextEditingController();
    final priceController = TextEditingController();
    final notesController = TextEditingController();

    String status = "pending";

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Create Job"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(labelText: "Client"),
                ),
                TextField(
                  controller: pickupController,
                  decoration: const InputDecoration(labelText: "Pickup"),
                ),
                TextField(
                  controller: dropoffController,
                  decoration: const InputDecoration(labelText: "Dropoff"),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: "Notes"),
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: "pending", child: Text("Pending")),
                    DropdownMenuItem(
                      value: "in progress",
                      child: Text("In Progress"),
                    ),
                    DropdownMenuItem(
                      value: "completed",
                      child: Text("Completed"),
                    ),
                  ],
                  onChanged: (value) => status = value!,
                  decoration: const InputDecoration(labelText: "Status"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('jobs').add({
                  'client': clientController.text,
                  'pickup': pickupController.text,
                  'dropoff': dropoffController.text,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'status': status,
                  'notes': notesController.text,
                  'createdAt': Timestamp.now(),
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

  // ================= UI =================
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

            // ================= FIRESTORE LIST =================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobs')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),

                builder: (context, snapshot) {
                  // Loading state
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // No data
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No jobs yet"));
                  }

                  final jobs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      final data = job.data() as Map<String, dynamic>;

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: getStatusColor(data['status']),
                            child: Text(
                              data['status'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),

                          title: Text(data['client']),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${data['pickup']} → ${data['dropoff']}"),
                              Text("\$${data['price']}"),
                              if (data['notes'] != null && data['notes'] != "")
                                Text("Notes: ${data['notes']}"),
                            ],
                          ),

                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              FirebaseFirestore.instance
                                  .collection('jobs')
                                  .doc(job.id)
                                  .delete();
                            },
                          ),
                        ),
                      );
                    },
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job.dart';

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
    final pickupController = TextEditingController();
    final dropoffController = TextEditingController();
    final priceController = TextEditingController();
    final notesController = TextEditingController();

    String status = "pending";
    String? selectedClientId;
    String? selectedClientName;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Create Job"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    // ================= CLIENT DROPDOWN =================
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('clients')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final clients = snapshot.data!.docs;

                        return DropdownButtonFormField<String>(
                          value: selectedClientId,
                          hint: const Text("Select Client"),
                          items: clients.map((client) {
                            final data = client.data() as Map<String, dynamic>;

                            return DropdownMenuItem(
                              value: client.id,
                              child: Text(data['name'] ?? 'No Name'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            final selected = clients.firstWhere(
                              (c) => c.id == value,
                            );
                            final data =
                                selected.data() as Map<String, dynamic>;

                            setDialogState(() {
                              selectedClientId = value;
                              selectedClientName = data['name'];
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 10),

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
                        DropdownMenuItem(
                          value: "pending",
                          child: Text("Pending"),
                        ),
                        DropdownMenuItem(
                          value: "in progress",
                          child: Text("In Progress"),
                        ),
                        DropdownMenuItem(
                          value: "completed",
                          child: Text("Completed"),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          status = value!;
                        });
                      },
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
                    // ================= VALIDATION =================
                    if (selectedClientId == null ||
                        pickupController.text.isEmpty ||
                        dropoffController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fill required fields")),
                      );
                      return;
                    }

                    // ================= CREATE JOB OBJECT =================
                    final newJob = Job(
                      id: '', // Firestore will generate
                      clientId: selectedClientId!,
                      clientName: selectedClientName ?? '',
                      pickup: pickupController.text,
                      dropoff: dropoffController.text,
                      price: double.tryParse(priceController.text) ?? 0,
                      status: status,
                      notes: notesController.text,
                      createdAt: DateTime.now(),
                    );

                    // ================= SAVE =================
                    await FirebaseFirestore.instance
                        .collection('jobs')
                        .add(newJob.toMap());

                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= JOB CARD =================
  Widget buildJobCard(Job job) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getStatusColor(job.status),
          child: Text(
            job.status[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),

        title: Text(job.clientName),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${job.pickup} → ${job.dropoff}"),
            Text("\$${job.price}"),
            if (job.notes != null && job.notes!.isNotEmpty)
              Text("Notes: ${job.notes}"),
          ],
        ),

        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            FirebaseFirestore.instance.collection('jobs').doc(job.id).delete();
          },
        ),
      ),
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

            // ================= STREAM =================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobs')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),

                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No jobs yet"));
                  }

                  final jobs = snapshot.data!.docs.map((doc) {
                    return Job.fromFirestore(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );
                  }).toList();

                  return ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      return buildJobCard(jobs[index]);
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

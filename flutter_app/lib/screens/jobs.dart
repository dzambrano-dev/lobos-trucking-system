import 'package:flutter/material.dart';
import '../models/job.dart';
import '../models/invoice.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final List<Job> jobs = [];

  // ================= SAVE JOBS =================
  Future<void> saveJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jobs.map((j) => j.toMap()).toList();
    await prefs.setString('jobs', jsonEncode(data));
  }

  // ================= LOAD JOBS =================
  Future<void> loadJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('jobs');

    if (jsonString != null) {
      final List decoded = jsonDecode(jsonString);

      setState(() {
        jobs.clear();
        jobs.addAll(decoded.map((e) => Job.fromMap(e)).toList());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadJobs();
  }

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
              onPressed: () {
                setState(() {
                  jobs.add(
                    Job(
                      client: clientController.text,
                      pickup: pickupController.text,
                      dropoff: dropoffController.text,
                      price: double.tryParse(priceController.text) ?? 0,
                      status: status,
                      notes: notesController.text.isEmpty
                          ? null
                          : notesController.text,
                    ),
                  );
                });

                saveJobs();
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ================= CREATE INVOICE =================
  Future<void> createInvoiceFromJob(Job job) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('invoices');

    List<Invoice> invoices = [];

    if (jsonString != null) {
      final List decoded = jsonDecode(jsonString);
      invoices = decoded.map((e) => Invoice.fromMap(e)).toList();
    }

    final newInvoice = Invoice(
      jobId: job.id,
      client: job.client,
      amount: job.price,
    );

    invoices.add(newInvoice);

    final data = invoices.map((i) => i.toMap()).toList();
    await prefs.setString('invoices', jsonEncode(data));

    // OPTIONAL: auto mark job completed
    setState(() {
      final index = jobs.indexWhere((j) => j.id == job.id);
      if (index != -1) {
        jobs[index] = jobs[index].copyWith(status: "completed");
      }
    });

    saveJobs();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Invoice created")));
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

            Expanded(
              child: jobs.isEmpty
                  ? const Center(child: Text("No jobs yet"))
                  : ListView.builder(
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: getStatusColor(job.status),
                              child: Text(
                                job.status[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),

                            title: Text(job.client),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${job.pickup} → ${job.dropoff}"),
                                Text("\$${job.price}"),
                                if (job.notes != null)
                                  Text("Notes: ${job.notes}"),
                              ],
                            ),

                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.receipt),
                                  onPressed: () => createInvoiceFromJob(job),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                      jobs.removeAt(index);
                                    });
                                    saveJobs();
                                  },
                                ),
                              ],
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

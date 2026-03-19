import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  // ================= CONTROLLERS =================
  final TextEditingController companyController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool isSaving = false;

  // ================= SAVE CLIENT =================
  Future<void> saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('clients').add({
        "name": companyController.text,
        "contact": contactController.text,
        "phone": phoneController.text,
        "email": emailController.text,
        "address": addressController.text,
        "createdAt": Timestamp.now(),
      });

      // Clear inputs
      companyController.clear();
      contactController.clear();
      phoneController.clear();
      emailController.clear();
      addressController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Client saved")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() {
      isSaving = false;
    });
  }

  // ================= DELETE CLIENT =================
  Future<void> deleteClient(String id) async {
    await FirebaseFirestore.instance.collection('clients').doc(id).delete();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Clients")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= FORM =================
            const Text(
              "Add Client",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: companyController,
                    decoration: const InputDecoration(
                      labelText: "Company Name",
                    ),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: "Contact Name",
                    ),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: "Phone"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: "Address"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveClient,
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Client"),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ================= CLIENT LIST =================
            const Text(
              "Clients",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clients')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),

              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clients = snapshot.data!.docs;

                if (clients.isEmpty) {
                  return const Text("No clients yet");
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("Company")),
                      DataColumn(label: Text("Contact")),
                      DataColumn(label: Text("Phone")),
                      DataColumn(label: Text("Email")),
                      DataColumn(label: Text("Actions")),
                    ],
                    rows: clients.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      return DataRow(
                        cells: [
                          DataCell(Text(data["name"] ?? "")),
                          DataCell(Text(data["contact"] ?? "")),
                          DataCell(Text(data["phone"] ?? "")),
                          DataCell(Text(data["email"] ?? "")),

                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteClient(doc.id),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    companyController.dispose();
    contactController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }
}

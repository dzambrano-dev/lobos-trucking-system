import 'package:flutter/material.dart';

// Import HTTP library so Flutter can call the backend API
import 'package:http/http.dart' as http;

// Import JSON tools so we can encode the request body
import 'dart:convert';

// ClientsPage is the main screen used to manage trucking clients
class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

// State class allows us to store form data and update UI
class _ClientsPageState extends State<ClientsPage> {
  // Controllers store text input from the form fields
  final TextEditingController companyController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // Global key used to validate the form
  final _formKey = GlobalKey<FormState>();

  // Loading state used to disable button during API call
  bool isSaving = false;

  /// Sends client data to FastAPI backend
  Future<void> saveClient() async {
    // Validate the form before sending
    if (!_formKey.currentState!.validate()) return;

    // Enable loading state
    setState(() {
      isSaving = true;
    });

    // Create JSON object from form fields
    final clientData = {
      "company_name": companyController.text,
      "contact_name": contactController.text,
      "phone": phoneController.text,
      "email": emailController.text,
      "address": addressController.text,
    };

    try {
      // Send POST request to backend
      final response = await http.post(
        Uri.parse("http://localhost:8000/clients"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(clientData),
      );

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Clear form fields after successful save
        companyController.clear();
        contactController.clear();
        phoneController.clear();
        emailController.clear();
        addressController.clear();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Client saved successfully")),
        );
      } else {
        // Backend returned an error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving client: ${response.body}")),
        );
      }
    } catch (e) {
      // Network error or server unreachable
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Connection error: $e")));
    }

    // Disable loading state
    setState(() {
      isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top navigation bar
      appBar: AppBar(title: const Text("Clients")),

      // Scrollable layout prevents keyboard overflow
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),

        // Form groups the input fields
        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Page Title
              const Text(
                "Add Client",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              /// Company Name
              TextFormField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: "Company Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Company name required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              /// Contact Name
              TextFormField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: "Contact Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Contact name required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              /// Phone
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Phone required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              /// Email
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Email required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              /// Address
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: "Address",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Address required";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 25),

              /// Save Button
              SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  // Disable button while saving
                  onPressed: isSaving ? null : saveClient,

                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Save Client"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dispose controllers when widget is destroyed
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

import 'package:flutter/material.dart';

import '../models/client_record.dart';
import '../services/client_repository.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _clients = ClientRepository();
  final _searchController = TextEditingController();
  String _query = '';

  Future<void> _openEditor([ClientRecord? client]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClientEditorDialog(repository: _clients, client: client),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(client == null ? 'Client added.' : 'Client updated.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New client'),
      ),
      body: StreamBuilder<List<ClientRecord>>(
        stream: _clients.watchClients(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _ClientState(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load clients',
              message: 'Check the connection and try again.',
            );
          }

          final allClients = snapshot.data ?? const [];
          final query = _query.toLowerCase();
          final visibleClients = allClients.where((client) {
            if (query.isEmpty) return true;
            return client.name.toLowerCase().contains(query) ||
                client.contact.toLowerCase().contains(query) ||
                client.phone.toLowerCase().contains(query);
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  labelText: 'Search clients',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (allClients.isEmpty)
                const _ClientState(
                  icon: Icons.business_outlined,
                  title: 'No clients yet',
                  message: 'Add the first customer to begin assigning loads.',
                )
              else if (visibleClients.isEmpty)
                const _ClientState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try a different company, contact, or phone number.',
                )
              else
                ...visibleClients.map(
                  (client) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.business_rounded),
                      ),
                      title: Text(
                        client.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          client.contact,
                          client.phone,
                          if (client.email.isNotEmpty) client.email,
                        ].where((value) => value.isNotEmpty).join(' • '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Edit client',
                        onPressed: () => _openEditor(client),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ClientEditorDialog extends StatefulWidget {
  const _ClientEditorDialog({required this.repository, required this.client});

  final ClientRepository repository;
  final ClientRecord? client;

  @override
  State<_ClientEditorDialog> createState() => _ClientEditorDialogState();
}

class _ClientEditorDialogState extends State<_ClientEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameController = TextEditingController(text: client?.name);
    _contactController = TextEditingController(text: client?.contact);
    _phoneController = TextEditingController(text: client?.phone);
    _emailController = TextEditingController(text: client?.email);
    _addressController = TextEditingController(text: client?.address);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final client = widget.client;
      if (client == null) {
        await widget.repository.createClient(
          name: _nameController.text,
          contact: _contactController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          address: _addressController.text,
        );
      } else {
        await widget.repository.updateClient(
          id: client.id,
          name: _nameController.text,
          contact: _contactController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          address: _addressController.text,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'The client could not be saved. Check the connection and '
            'retry.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.client == null ? 'Add client' : 'Edit client'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_nameController, 'Company name', maxLength: 150),
                _field(_contactController, 'Contact name', maxLength: 120),
                _field(
                  _phoneController,
                  'Phone',
                  maxLength: 40,
                  keyboardType: TextInputType.phone,
                ),
                _field(
                  _emailController,
                  'Email',
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isNotEmpty &&
                        (!email.contains('@') || !email.contains('.'))) {
                      return 'Enter a valid email or leave it blank.';
                    }
                    return null;
                  },
                ),
                _field(_addressController, 'Billing address', maxLength: 300),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save client'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required int maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textCapitalization: keyboardType == TextInputType.emailAddress
            ? TextCapitalization.none
            : TextCapitalization.words,
        decoration: InputDecoration(labelText: label),
        validator:
            validator ??
            (value) =>
                value == null || value.trim().isEmpty ? 'Required.' : null,
      ),
    );
  }
}

class _ClientState extends StatelessWidget {
  const _ClientState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

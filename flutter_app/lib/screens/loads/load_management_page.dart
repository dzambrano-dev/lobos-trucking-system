import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/load_record.dart';
import '../../services/load_repository.dart';
import '../../services/user_repository.dart';
import '../../widgets/load_status_chip.dart';

class LoadManagementPage extends StatefulWidget {
  const LoadManagementPage({super.key, required this.user});

  final AppUser user;

  @override
  State<LoadManagementPage> createState() => _LoadManagementPageState();
}

class _LoadManagementPageState extends State<LoadManagementPage> {
  final _loads = LoadRepository();
  bool _loadingCreateData = false;

  Future<void> _openCreateLoad() async {
    setState(() => _loadingCreateData = true);

    try {
      final drivers = await UserRepository().getActiveDrivers();
      final clientSnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .orderBy('name')
          .get();
      final clients = clientSnapshot.docs
          .map(
            (doc) => _ClientChoice(
              id: doc.id,
              name: doc.data()['name'] as String? ?? 'Unnamed client',
            ),
          )
          .toList();

      if (!mounted) return;
      if (drivers.isEmpty || clients.isEmpty) {
        final missing = [
          if (clients.isEmpty) 'at least one client',
          if (drivers.isEmpty) 'at least one active driver',
        ].join(' and ');
        _showMessage('Create $missing before assigning a load.');
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CreateLoadDialog(
          actor: widget.user,
          clients: clients,
          drivers: drivers,
          repository: _loads,
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not prepare the form: $error');
    } finally {
      if (mounted) setState(() => _loadingCreateData = false);
    }
  }

  Future<void> _resolveIssue(LoadRecord load) async {
    try {
      await _loads.resolveIssue(load: load, actor: widget.user);
      if (mounted) _showMessage('Issue marked resolved.');
    } catch (error) {
      if (mounted) _showMessage('Could not resolve issue: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Load management')),
      floatingActionButton: widget.user.permissions.manageLoads
          ? FloatingActionButton.extended(
              onPressed: _loadingCreateData ? null : _openCreateLoad,
              icon: _loadingCreateData
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('New load'),
            )
          : null,
      body: StreamBuilder<List<LoadRecord>>(
        stream: _loads.watchAllLoads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load deliveries',
              message: snapshot.error.toString(),
            );
          }

          final loads = snapshot.data ?? const [];
          if (loads.isEmpty) {
            return const _StateMessage(
              icon: Icons.inventory_2_outlined,
              title: 'No loads yet',
              message: 'Create and assign the first load.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: loads.length,
            itemBuilder: (context, index) {
              final load = loads[index];
              return _ManagerLoadCard(
                load: load,
                canManage: widget.user.permissions.manageLoads,
                onResolveIssue: () => _resolveIssue(load),
              );
            },
          );
        },
      ),
    );
  }
}

class _ManagerLoadCard extends StatelessWidget {
  const _ManagerLoadCard({
    required this.load,
    required this.canManage,
    required this.onResolveIssue,
  });

  final LoadRecord load;
  final bool canManage;
  final VoidCallback onResolveIssue;

  @override
  Widget build(BuildContext context) {
    final scheduled = load.scheduledPickupAt == null
        ? 'Pickup time unavailable'
        : DateFormat('EEE, MMM d • h:mm a').format(load.scheduledPickupAt!);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        load.clientName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(load.loadNumber),
                    ],
                  ),
                ),
                LoadStatusChip(status: load.status),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(icon: Icons.schedule_rounded, text: scheduled),
            _DetailRow(
              icon: Icons.person_outline_rounded,
              text: load.assignedDriverName,
            ),
            _DetailRow(
              icon: Icons.trip_origin_rounded,
              text: load.pickupAddress,
            ),
            _DetailRow(
              icon: Icons.location_on_outlined,
              text: load.deliveryAddress,
            ),
            if (load.needsAttention) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver reported a problem',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (load.issueSummary?.isNotEmpty == true)
                      Text(load.issueSummary!),
                    if (canManage) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onResolveIssue,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Mark resolved'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateLoadDialog extends StatefulWidget {
  const _CreateLoadDialog({
    required this.actor,
    required this.clients,
    required this.drivers,
    required this.repository,
  });

  final AppUser actor;
  final List<_ClientChoice> clients;
  final List<AppUser> drivers;
  final LoadRepository repository;

  @override
  State<_CreateLoadDialog> createState() => _CreateLoadDialogState();
}

class _CreateLoadDialogState extends State<_CreateLoadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _deliveryController = TextEditingController();
  _ClientChoice? _client;
  AppUser? _driver;
  DateTime _scheduledPickupAt = DateTime.now();
  bool _saving = false;

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledPickupAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledPickupAt),
    );
    if (time == null) return;

    setState(() {
      _scheduledPickupAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _client == null ||
        _driver == null) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.repository.createLoad(
        clientId: _client!.id,
        clientName: _client!.name,
        pickupAddress: _pickupController.text,
        deliveryAddress: _deliveryController.text,
        scheduledPickupAt: _scheduledPickupAt,
        driver: _driver!,
        actor: widget.actor,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create load: $error')));
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _deliveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create and assign load'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<_ClientChoice>(
                  initialValue: _client,
                  items: widget.clients
                      .map(
                        (client) => DropdownMenuItem(
                          value: client,
                          child: Text(client.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _client = value),
                  decoration: const InputDecoration(labelText: 'Client'),
                  validator: (value) =>
                      value == null ? 'Select a client.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AppUser>(
                  initialValue: _driver,
                  items: widget.drivers
                      .map(
                        (driver) => DropdownMenuItem(
                          value: driver,
                          child: Text(driver.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _driver = value),
                  decoration: const InputDecoration(
                    labelText: 'Assigned driver',
                  ),
                  validator: (value) =>
                      value == null ? 'Select a driver.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pickupController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Pickup address',
                    prefixIcon: Icon(Icons.trip_origin_rounded),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deliveryController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Scheduled pickup'),
                  subtitle: Text(
                    DateFormat(
                      'EEE, MMM d, yyyy • h:mm a',
                    ).format(_scheduledPickupAt),
                  ),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: _pickSchedule,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Creating…' : 'Create load'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required.' : null;
  }
}

class _ClientChoice {
  const _ClientChoice({required this.id, required this.name});

  final String id;
  final String name;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

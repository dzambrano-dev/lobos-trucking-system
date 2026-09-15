import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../services/operations.dart';
import '../invoice_workspace.dart';
import '../../models/load_record.dart';
import '../../models/dispatch_queue.dart';
import '../../services/client_repository.dart';
import '../../services/load_repository.dart';
import '../../services/user_repository.dart';
import '../../widgets/delivery_proof_dialog.dart';
import '../../widgets/load_status_chip.dart';

class LoadManagementPage extends StatefulWidget {
  const LoadManagementPage({
    super.key,
    required this.user,
    this.store,
    this.embedded = false,
  });

  final AppUser user;
  final Operations? store;
  final bool embedded;

  @override
  State<LoadManagementPage> createState() => _LoadManagementPageState();
}

class _LoadManagementPageState extends State<LoadManagementPage> {
  late final store = widget.store ?? Operations();
  late final _loads = LoadRepository(firestore: store.db);
  late final loadStream = _loads.watchAllLoads();
  late final jobStream = store.watch('jobs');
  bool billing = false;
  bool _loadingCreateData = false;

  Future<void> _bill(LoadRecord load) async {
    if (billing) return;
    setState(() => billing = true);
    try {
      final existing = await store.db
          .collection('jobs')
          .doc('load_${load.id}')
          .get();
      double amount = number(existing.data()?['price']);
      if (!existing.exists) {
        if (!mounted) return;
        var charge = '';
        final form = GlobalKey<FormState>();
        final result = await showDialog<double>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Invoice ${load.loadNumber}'),
            content: Form(
              key: form,
              child: TextFormField(
                onChanged: (value) => charge = value,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: r'Agreed charge ($)',
                ),
                validator: (value) {
                  final n = double.tryParse(value ?? '');
                  return n == null ||
                          !n.isFinite ||
                          n <= 0 ||
                          n > 999999999 ||
                          (n * 100 - (n * 100).round()).abs() > 0.00001
                      ? 'Enter a positive charge with up to two decimals'
                      : null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, double.parse(charge));
                  }
                },
                child: const Text('Create invoice'),
              ),
            ],
          ),
        );
        if (result == null) return;
        amount = result;
      }
      final id = await store.billDeliveredLoad(load.id, amount);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoiceWorkspace(id: id, store: store),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Invoice could not be opened: $error');
    } finally {
      if (mounted) setState(() => billing = false);
    }
  }

  Future<void> _openCreateLoad() async {
    setState(() => _loadingCreateData = true);

    try {
      final drivers = await UserRepository().getActiveDrivers();
      final clientRecords = await ClientRepository().getClients();
      final clients = clientRecords
          .map((client) => _ClientChoice(id: client.id, name: client.name))
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
    } on InvalidUserProfileException catch (error) {
      debugPrint('Load form setup failed: $error');
      if (mounted) {
        _showMessage(
          'Repair users/${error.uid}: ${error.reason} '
          'The document ID must be the employee Authentication UID.',
        );
      }
    } catch (error) {
      debugPrint('Load form setup failed: $error');
      if (mounted) {
        _showMessage('The load form could not open. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingCreateData = false);
    }
  }

  Future<void> _resolveIssue(LoadRecord load) async {
    try {
      await _loads.resolveIssue(load: load, actor: widget.user);
      if (mounted) _showMessage('Issue marked resolved.');
    } catch (error) {
      debugPrint('Issue resolution failed: $error');
      if (mounted) {
        _showMessage('The issue could not be resolved. Please try again.');
      }
    }
  }

  Future<void> _viewProof(LoadRecord load) {
    return showDeliveryProofDialog(
      context: context,
      load: load,
      repository: _loads,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Dispatch'),
      ),
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
      body: StreamBuilder<List<Record>>(
        stream: jobStream,
        builder: (context, jobs) {
          final billed = {
            for (final job in jobs.data ?? <Record>[])
              if (job['loadId'] != null && job['invoiceId'] != null)
                job['loadId'].toString(),
          };
          final billingReady = jobs.hasData && !jobs.hasError;
          return StreamBuilder<List<LoadRecord>>(
            stream: loadStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const _StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Unable to load deliveries',
                  message: 'Check the connection and try again.',
                );
              }

              final now = DateTime.now();
              final loads = [...snapshot.data ?? <LoadRecord>[]]
                ..sort((a, b) {
                  final group = dispatchGroup(
                    a,
                    billed,
                    now,
                  ).compareTo(dispatchGroup(b, billed, now));
                  if (group != 0) return group;
                  final byDate = (a.scheduledPickupAt ?? DateTime(2100))
                      .compareTo(b.scheduledPickupAt ?? DateTime(2100));
                  return byDate != 0 ? byDate : a.id.compareTo(b.id);
                });
              if (loads.isEmpty) {
                return const _StateMessage(
                  icon: Icons.inventory_2_outlined,
                  title: 'No loads yet',
                  message: 'Create and assign the first load.',
                );
              }

              return Column(
                children: [
                  if (!billingReady)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        jobs.hasError
                            ? 'Billing status is unavailable. Refresh before invoicing.'
                            : 'Checking invoice status...',
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: loads.length,
                      itemBuilder: (context, index) {
                        final load = loads[index];
                        final group = dispatchGroup(load, billed, now);
                        final first =
                            index == 0 ||
                            dispatchGroup(loads[index - 1], billed, now) !=
                                group;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (first)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  dispatchGroupLabels[group],
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            _ManagerLoadCard(
                              load: load,
                              canManage: widget.user.permissions.manageLoads,
                              onResolveIssue: () => _resolveIssue(load),
                              invoiceExists: billed.contains(load.id),
                              onBill:
                                  billingReady &&
                                      !billing &&
                                      widget.user.isAdmin &&
                                      load.isComplete
                                  ? () => _bill(load)
                                  : null,
                              onViewProof: load.hasDeliveryProof
                                  ? () => _viewProof(load)
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
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
    required this.onViewProof,
    required this.onBill,
    required this.invoiceExists,
  });

  final LoadRecord load;
  final bool canManage;
  final VoidCallback onResolveIssue;
  final VoidCallback? onViewProof;
  final VoidCallback? onBill;
  final bool invoiceExists;

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
            if (onBill != null)
              OutlinedButton.icon(
                onPressed: onBill,
                icon: const Icon(Icons.receipt_long),
                label: Text(invoiceExists ? 'View invoice' : 'Create invoice'),
              ),
            if (onViewProof != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onViewProof,
                icon: const Icon(Icons.draw_rounded),
                label: Text(
                  load.signedByName?.isNotEmpty == true
                      ? 'View signature from ${load.signedByName}'
                      : 'View delivery proof',
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
  String? _saveError;

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

    setState(() {
      _saving = true;
      _saveError = null;
    });

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
      debugPrint('Load creation failed: $error');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = _creationFailureMessage(error);
      });
    }
  }

  String _creationFailureMessage(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firebase rejected this load. Verify users/${widget.actor.uid} '
          'and users/${_driver!.uid} use the employees’ Authentication UIDs, '
          'have valid permissions maps, and contain the exact display names '
          'shown above.';
    }
    return 'The load could not be created. Check the connection and try again.';
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
                  maxLength: 300,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deliveryController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: _required,
                  maxLength: 300,
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
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _saveError!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

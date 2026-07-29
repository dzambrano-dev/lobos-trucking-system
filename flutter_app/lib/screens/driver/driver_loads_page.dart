import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/load_record.dart';
import '../../models/load_status.dart';
import '../../services/load_repository.dart';
import '../../widgets/load_status_chip.dart';
import 'customer_signature_page.dart';

class DriverLoadsPage extends StatefulWidget {
  const DriverLoadsPage({super.key, required this.user});

  final AppUser user;

  @override
  State<DriverLoadsPage> createState() => _DriverLoadsPageState();
}

class _DriverLoadsPageState extends State<DriverLoadsPage> {
  final _loads = LoadRepository();
  String? _busyLoadId;

  Future<void> _advance(LoadRecord load) async {
    final next = load.status.next;
    if (next == null) return;

    if (next == LoadProgressStatus.delivered) {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CustomerSignaturePage(
            load: load,
            user: widget.user,
            repository: _loads,
          ),
        ),
      );
      if (completed == true && mounted) {
        _showMessage('Delivery completed and signed.');
      }
      return;
    }

    setState(() => _busyLoadId = load.id);
    try {
      await _loads.updateProgress(load: load, next: next, actor: widget.user);
      if (mounted) _showMessage('Updated to ${next.label}.');
    } catch (error) {
      if (mounted) _showMessage('Could not update load: $error');
    } finally {
      if (mounted) setState(() => _busyLoadId = null);
    }
  }

  Future<void> _reportIssue(LoadRecord load) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report delay or problem'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What happened?',
            hintText: 'Example: Waiting for a dock at the delivery location',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Send report'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note == null) return;
    setState(() => _busyLoadId = load.id);
    try {
      await _loads.reportIssue(load: load, actor: widget.user, note: note);
      if (mounted) _showMessage('Problem reported to the office.');
    } catch (error) {
      if (mounted) _showMessage('Could not send report: $error');
    } finally {
      if (mounted) setState(() => _busyLoadId = null);
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
      appBar: AppBar(title: const Text('My deliveries')),
      body: StreamBuilder<List<LoadRecord>>(
        stream: _loads.watchAssignedLoads(widget.user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DriverStateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Unable to load assignments',
              message: snapshot.error.toString(),
            );
          }

          final loads = snapshot.data ?? const [];
          if (loads.isEmpty) {
            return const _DriverStateMessage(
              icon: Icons.route_outlined,
              title: 'No assigned loads',
              message: 'New assignments will appear here automatically.',
            );
          }

          final openLoads = loads.where((load) => !load.isClosed).toList();
          final completedLoads = loads
              .where((load) => load.isComplete)
              .take(10)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (openLoads.isNotEmpty) ...[
                Text('Active', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ...openLoads.map(
                  (load) => _DriverLoadCard(
                    load: load,
                    busy: _busyLoadId == load.id,
                    onAdvance: () => _advance(load),
                    onReportIssue: () => _reportIssue(load),
                  ),
                ),
              ],
              if (completedLoads.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Recently delivered',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                ...completedLoads.map(
                  (load) => _DriverLoadCard(
                    load: load,
                    busy: false,
                    onAdvance: null,
                    onReportIssue: null,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DriverLoadCard extends StatelessWidget {
  const _DriverLoadCard({
    required this.load,
    required this.busy,
    required this.onAdvance,
    required this.onReportIssue,
  });

  final LoadRecord load;
  final bool busy;
  final VoidCallback? onAdvance;
  final VoidCallback? onReportIssue;

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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(load.loadNumber),
                    ],
                  ),
                ),
                LoadStatusChip(status: load.status),
              ],
            ),
            const SizedBox(height: 14),
            _DriverDetail(
              icon: Icons.schedule_rounded,
              label: 'Pickup',
              value: scheduled,
            ),
            _DriverDetail(
              icon: Icons.trip_origin_rounded,
              label: 'From',
              value: load.pickupAddress,
            ),
            _DriverDetail(
              icon: Icons.location_on_rounded,
              label: 'To',
              value: load.deliveryAddress,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        load.issueSummary ?? 'Problem reported to the office',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (onAdvance != null || onReportIssue != null) ...[
              const SizedBox(height: 16),
              if (onAdvance != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onAdvance,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            load.status == LoadProgressStatus.inTransit
                                ? Icons.draw_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(load.status.nextActionLabel!),
                  ),
                ),
              if (onReportIssue != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReportIssue,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Report delay or problem'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DriverDetail extends StatelessWidget {
  const _DriverDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStateMessage extends StatelessWidget {
  const _DriverStateMessage({
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
            Icon(icon, size: 60),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

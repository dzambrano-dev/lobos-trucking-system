import 'package:flutter/material.dart';

import '../models/load_status.dart';

class LoadStatusChip extends StatelessWidget {
  const LoadStatusChip({super.key, required this.status});

  final LoadProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      LoadProgressStatus.assigned => (Colors.blueGrey, Icons.assignment),
      LoadProgressStatus.accepted => (Colors.blue, Icons.check_circle),
      LoadProgressStatus.arrivedAtPickup => (
        Colors.deepOrange,
        Icons.location_on,
      ),
      LoadProgressStatus.inTransit => (Colors.indigo, Icons.local_shipping),
      LoadProgressStatus.delivered => (Colors.green, Icons.task_alt),
      LoadProgressStatus.cancelled => (Colors.grey, Icons.cancel),
    };

    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(status.label),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }
}

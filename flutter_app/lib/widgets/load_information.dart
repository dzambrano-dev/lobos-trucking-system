import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/load_record.dart';
import 'contact_links.dart';

class LoadInformation extends StatelessWidget {
  const LoadInformation({super.key, required this.load});
  final LoadRecord load;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ContactLink(kind: 'address', text: load.pickupAddress, label: 'Pickup'),
      ContactLink(
        kind: 'address',
        text: load.deliveryAddress,
        label: 'Delivery',
      ),
      if (load.pickupNumber.isNotEmpty) Text('Pickup #: ${load.pickupNumber}'),
      if (load.reference.isNotEmpty) Text('Reference #: ${load.reference}'),
      if (load.scheduledDeliveryAt != null)
        Text(
          'Planned delivery: ${DateFormat('MMM d, yyyy • h:mm a').format(load.scheduledDeliveryAt!)}',
        ),
      if (load.contact.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClientContactCard(
            name: load.contact['name'] ?? '',
            phone: load.contact['phone'] ?? '',
            email: load.contact['email'] ?? '',
          ),
        ),
      if (load.driverNotes.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver instructions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(load.driverNotes),
            ],
          ),
        ),
    ],
  );
}

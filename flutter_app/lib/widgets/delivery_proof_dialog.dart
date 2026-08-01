import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/delivery_proof.dart';
import '../models/load_record.dart';
import '../services/load_repository.dart';

Future<void> showDeliveryProofDialog({
  required BuildContext context,
  required LoadRecord load,
  required LoadRepository repository,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Proof of delivery • ${load.loadNumber}'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<DeliveryProof>(
          // Proof bytes are fetched only when somebody asks to see them. That
          // keeps the normal manager and driver screens quick on mobile data.
          future: repository.getDeliveryProof(load.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'The saved delivery proof could not be loaded. Try again '
                  'when the connection is stable.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            final proof = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Received by ${proof.signedByName}'),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(proof.signedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    height: 240,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.memory(
                      proof.signaturePng,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('The signature image is invalid.'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

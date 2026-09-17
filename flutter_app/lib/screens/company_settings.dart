import 'package:flutter/material.dart';
import '../services/operations.dart';
import '../widgets/record_editor.dart';

Future<void> openCompanySettings(BuildContext context, Operations store) async {
  try {
    final snapshot = await store.db.collection('settings').doc('company').get();
    if (!context.mounted) return;
    await editRecord(
      context,
      title: 'Company & invoice details',
      initial: snapshot.data() ?? {'name': 'Lobos Trucking'},
      fields: const [
        FieldSpec('name', 'Company name', required: true),
        FieldSpec(
          'address',
          'Business / remittance address',
          required: true,
          multiline: true,
        ),
        FieldSpec('phone', 'Phone'),
        FieldSpec('email', 'Billing email'),
        FieldSpec(
          'paymentInstructions',
          'Payment instructions',
          multiline: true,
        ),
      ],
      onSave: store.saveCompany,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load company details. Check your connection and access.',
          ),
        ),
      );
    }
  }
}

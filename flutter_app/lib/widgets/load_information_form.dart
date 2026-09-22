import '../models/load_status.dart';
import 'package:flutter/material.dart';
import '../models/load_record.dart';
import '../models/app_user.dart';
import '../services/load_repository.dart';
import 'record_editor.dart';

const loadInformationFields = [
  FieldSpec('pickupNumber', 'Pickup # (optional)'),
  FieldSpec('reference', 'Reference # (optional)'),
  FieldSpec(
    'scheduledDeliveryAt',
    'Planned delivery (optional)',
    dateTime: true,
  ),
  FieldSpec('contactName', 'Trip contact name'),
  FieldSpec('contactPhone', 'Trip contact phone'),
  FieldSpec('contactEmail', 'Trip contact email'),
  FieldSpec('driverNotes', 'Driver notes / instructions', multiline: true),
];
Map<String, dynamic> loadInformationData(Map<String, dynamic> data) => {
  'pickupNumber': data['pickupNumber'],
  'reference': data['reference'],
  'scheduledDeliveryAt': data['scheduledDeliveryAt'],
  'driverNotes': data['driverNotes'],
  'contact': {
    'name': data['contactName'],
    'phone': data['contactPhone'],
    'email': data['contactEmail'],
  },
};
Future<bool?> editLoadInformation(
  BuildContext context,
  LoadRecord load,
  LoadRepository repository,
  AppUser actor,
) => editRecord(
  context,
  title: 'Driver instructions & load details',
  fields: loadInformationFields,
  initial: {
    'scheduledPickupAt': load.scheduledPickupAt,
    'pickupNumber': load.pickupNumber,
    'reference': load.reference,
    'driverNotes': load.driverNotes,
    'scheduledDeliveryAt':
        load.scheduledDeliveryAt
            ?.toIso8601String()
            .substring(0, 16)
            .replaceAll('T', ' ') ??
        '',
    'contactName': load.contact['name'],
    'contactPhone': load.contact['phone'],
    'contactEmail': load.contact['email'],
  },
  onSave: (data) => repository.updateInformation(
    loadId: load.id,
    actor: actor,
    information: loadInformationData(data),
  ),
);

Future<bool?> correctLoadStatus(
  BuildContext context,
  LoadRecord load,
  LoadRepository repository,
  AppUser actor,
) => editRecord(
  context,
  title: 'Correct load status',
  fields: [
    FieldSpec(
      'status',
      'New status',
      required: true,
      options: {
        for (final status in LoadProgressStatus.values)
          if (status != load.status) status.value: status.label,
      },
    ),
    const FieldSpec(
      'reason',
      'Reason (saved in history)',
      required: true,
      multiline: true,
    ),
  ],
  initial: const {},
  onSave: (data) => repository.correctStatus(
    load: load,
    next: LoadProgressStatus.fromValue(data['status']),
    actor: actor,
    reason: data['reason'].toString(),
  ),
);

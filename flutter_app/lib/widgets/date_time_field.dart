import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.controller,
    required this.label,
    this.seed,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final DateTime? seed;
  final bool enabled;
  Future<void> choose(BuildContext context) async {
    final initial =
        DateTime.tryParse(controller.text) ?? seed ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;
    controller.text = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextFormField(
          controller: controller,
          readOnly: true,
          enabled: enabled,
          onTap: () => choose(context),
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Choose date and time',
            prefixIcon: const Icon(Icons.event),
            suffixIcon: value.text.isEmpty
                ? const Icon(Icons.expand_more)
                : IconButton(
                    tooltip: 'Clear planned delivery',
                    onPressed: enabled ? controller.clear : null,
                    icon: const Icon(Icons.clear),
                  ),
            helperText: 'Local time',
          ),
        ),
      );
}

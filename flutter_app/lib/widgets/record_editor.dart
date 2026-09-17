import 'package:flutter/material.dart';
import '../services/operations.dart';

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.required = false,
    this.numeric = false,
    this.date = false,
    this.multiline = false,
    this.options,
  });
  final String key, label;
  final bool required, numeric, date, multiline;
  final Map<String, String>? options;
}

Future<bool?> editRecord(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Record initial = const {},
  required Future<void> Function(Record) onSave,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => RecordEditor(
    title: title,
    fields: fields,
    initial: initial,
    onSave: onSave,
  ),
);

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.title,
    required this.fields,
    required this.initial,
    required this.onSave,
  });
  final String title;
  final List<FieldSpec> fields;
  final Record initial;
  final Future<void> Function(Record) onSave;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final v = widget.initial[f.key];
      final d = f.date ? dateOf(v) : null;
      controllers[f.key] = TextEditingController(
        text: d != null
            ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
            : v?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final data = <String, dynamic>{};
      for (final f in widget.fields) {
        final v = controllers[f.key]!.text.trim();
        data[f.key] = f.numeric
            ? double.parse(v)
            : f.date
            ? (v.isEmpty ? null : DateTime.parse(v))
            : v;
      }
      await widget.onSave(data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error =
              'Could not save. ${e.toString().replaceFirst('Bad state: ', '')}';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: f.options != null
                        ? DropdownButtonFormField<String>(
                            initialValue:
                                f.options!.containsKey(controllers[f.key]!.text)
                                ? controllers[f.key]!.text
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: f.label),
                            items: f.options!.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: saving
                                ? null
                                : (v) => controllers[f.key]!.text = v ?? '',
                            validator: (v) =>
                                f.required && (v == null || v.isEmpty)
                                ? 'Select ${f.label.toLowerCase()}'
                                : null,
                          )
                        : TextFormField(
                            controller: controllers[f.key],
                            enabled: !saving,
                            maxLines: f.multiline ? 3 : 1,
                            keyboardType: f.numeric
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                  )
                                : f.key == 'email'
                                ? TextInputType.emailAddress
                                : f.key == 'phone'
                                ? TextInputType.phone
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: f.label,
                              hintText: f.date ? 'YYYY-MM-DD' : null,
                              suffixIcon: f.date
                                  ? IconButton(
                                      tooltip: 'Choose date',
                                      icon: const Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                      onPressed: saving
                                          ? null
                                          : () async {
                                              final d = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    dateOf(
                                                      controllers[f.key]!.text,
                                                    ) ??
                                                    DateTime.now(),
                                                firstDate: DateTime(1900),
                                                lastDate: DateTime(2200),
                                              );
                                              if (d != null) {
                                                controllers[f.key]!.text = d
                                                    .toIso8601String()
                                                    .split('T')
                                                    .first;
                                              }
                                            },
                                    )
                                  : null,
                            ),
                            validator: (raw) {
                              final v = raw?.trim() ?? '';
                              if ((f.required || f.numeric) && v.isEmpty) {
                                return 'Enter ${f.label.toLowerCase()}';
                              }
                              if (f.numeric) {
                                final n = double.tryParse(v);
                                if (n == null ||
                                    !n.isFinite ||
                                    n <= 0 ||
                                    n > 999999999 ||
                                    (n * 100 - (n * 100).round()).abs() >
                                        0.00001) {
                                  return 'Enter a positive amount with up to 2 decimals';
                                }
                              }
                              if (f.date && v.isNotEmpty) {
                                final d = DateTime.tryParse(v);
                                if (d == null ||
                                    d.toIso8601String().split('T').first != v) {
                                  return 'Use a valid date: YYYY-MM-DD';
                                }
                              }
                              if (f.key == 'email' &&
                                  v.isNotEmpty &&
                                  !RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(v)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../models/app_user.dart';
import '../../models/load_record.dart';
import '../../services/load_repository.dart';

class CustomerSignaturePage extends StatefulWidget {
  const CustomerSignaturePage({
    super.key,
    required this.load,
    required this.user,
    required this.repository,
  });

  final LoadRecord load;
  final AppUser user;
  final LoadRepository repository;

  @override
  State<CustomerSignaturePage> createState() => _CustomerSignaturePageState();
}

class _CustomerSignaturePageState extends State<CustomerSignaturePage> {
  late final SignatureController _signatureController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  Future<void> _completeDelivery() async {
    if (_signatureController.isEmpty) {
      setState(() => _error = 'The customer must sign before delivery.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final signature = await _signatureController.toPngBytes(
        width: 1200,
        height: 600,
      );
      if (signature == null || signature.isEmpty) {
        throw StateError('The signature image could not be created.');
      }

      await widget.repository.completeDelivery(
        load: widget.load,
        actor: widget.user,
        signaturePng: signature,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not complete delivery: $error';
      });
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer signature')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.load.clientName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(widget.load.loadNumber),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'By signing below, the customer confirms that this '
                      'delivery was received.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sign inside the box',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving ? null : () => _signatureController.clear(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Clear signature'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _saving ? null : _completeDelivery,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.task_alt_rounded),
              label: Text(
                _saving ? 'Saving delivery…' : 'Confirm signed delivery',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

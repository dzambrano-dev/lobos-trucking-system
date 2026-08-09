import 'dart:typed_data';

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
  final _signerNameController = TextEditingController();
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
    final signerName = _signerNameController.text.trim();
    if (signerName.isEmpty) {
      setState(() => _error = 'Enter the name of the person signing.');
      return;
    }
    if (_signatureController.isEmpty) {
      setState(() => _error = 'The customer must sign before delivery.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final signature = await _renderSmallSignature();

      await widget.repository.completeDelivery(
        load: widget.load,
        actor: widget.user,
        signaturePng: signature,
        signedByName: signerName,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Delivery could not be completed: $error');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'The delivery could not be saved. Check the connection and '
            'try again.';
      });
    }
  }

  Future<Uint8List> _renderSmallSignature() async {
    // Try a crisp size first, then a smaller canvas if a particularly complex
    // signature crosses our Firestore safety limit.
    for (final size in const [(800, 360), (600, 270)]) {
      final bytes = await _signatureController.toPngBytes(
        width: size.$1,
        height: size.$2,
      );
      if (bytes == null) continue;
      if (bytes.isNotEmpty &&
          bytes.length <= LoadRepository.maxSignatureBytes) {
        return bytes;
      }
    }
    throw StateError('The signature is too large. Clear it and try again.');
  }

  @override
  void dispose() {
    _signerNameController.dispose();
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
            TextField(
              controller: _signerNameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Customer name',
                hintText: 'Name of the person receiving the delivery',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 8),
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

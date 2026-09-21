import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Uri contactUri(String kind, String text) => switch (kind) {
  'phone' => Uri(
    scheme: 'tel',
    path: text
        .split(RegExp(r'(?:ext\.?|x|;ext=|#)', caseSensitive: false))
        .first
        .replaceAll(RegExp(r'[^0-9+]'), ''),
  ),
  'email' => Uri(scheme: 'mailto', path: text.trim()),
  _ => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': text.trim(),
  }),
};

class ContactLink extends StatelessWidget {
  const ContactLink({
    super.key,
    required this.kind,
    required this.text,
    this.label,
  });
  final String kind, text;
  final String? label;
  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            ),
            icon: Icon(
              kind == 'phone'
                  ? Icons.phone_outlined
                  : kind == 'email'
                  ? Icons.email_outlined
                  : Icons.location_on_outlined,
              size: 20,
            ),
            label: Text(label == null ? text : '$label: $text'),
            onPressed: () async {
              try {
                if (await launchUrl(
                  contactUri(kind, text),
                  mode: LaunchMode.externalApplication,
                )) {
                  return;
                }
              } catch (_) {}
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No application opened. Use the copy button instead.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
        IconButton(
          tooltip: 'Copy ${label ?? kind}',
          icon: const Icon(Icons.copy_outlined, size: 16),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied.')));
            }
          },
        ),
      ],
    );
  }
}

class ClientContactCard extends StatelessWidget {
  const ClientContactCard({
    super.key,
    this.company = '',
    this.name = '',
    this.phone = '',
    this.email = '',
    this.address = '',
  });
  final String company, name, phone, email, address;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (company.isNotEmpty)
        Text(company, style: Theme.of(context).textTheme.titleMedium),
      if (name.isNotEmpty) Text(name),
      if (phone.isNotEmpty) ContactLink(kind: 'phone', text: phone),
      if (email.isNotEmpty) ContactLink(kind: 'email', text: email),
      if (address.isNotEmpty)
        ContactLink(kind: 'address', text: address, label: 'Billing address'),
    ],
  );
}

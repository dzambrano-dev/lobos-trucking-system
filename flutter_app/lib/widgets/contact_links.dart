import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Uri contactUri(String kind, String text) => switch (kind) {
  'phone' || 'sms' => Uri(
    scheme: kind == 'sms' ? 'sms' : 'tel',
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

Future<void> openContactLink(
  BuildContext context,
  String kind,
  String text,
) async {
  try {
    if (await launchUrl(
      contactUri(kind, text),
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      webOnlyWindowName: kind == 'phone' || kind == 'sms' || kind == 'email'
          ? '_self'
          : '_blank',
    )) {
      return;
    }
  } catch (error) {
    debugPrint('Contact link failed ($kind): $error');
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kind == 'phone' || kind == 'sms'
              ? 'Your browser could not open a phone or messaging app. Try this link on your phone, or copy the number.'
              : 'The link could not open. Check your browser settings or copy the address.',
        ),
      ),
    );
  }
}

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
            onPressed: () => openContactLink(context, kind, text),
          ),
        ),
        if (kind == 'phone')
          IconButton(
            tooltip: 'Text this number',
            icon: const Icon(Icons.sms_outlined, size: 20),
            onPressed: () => openContactLink(context, 'sms', text),
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../clients.dart';
import '../driver/driver_loads_page.dart';
import '../loads/load_management_page.dart';

class ManagerHomePage extends StatelessWidget {
  const ManagerHomePage({super.key, required this.user});

  final AppUser user;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobos Trucking'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: FirebaseAuth.instance.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome, ${user.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text('Loads requiring attention should be handled first.'),
            const SizedBox(height: 24),
            if (user.permissions.manageLoads || user.permissions.viewAllLoads)
              _HomeActionCard(
                icon: Icons.local_shipping_rounded,
                title: 'Load management',
                subtitle: user.permissions.manageLoads
                    ? 'Create, assign, and review every load'
                    : 'Review company loads',
                onTap: () => _open(context, LoadManagementPage(user: user)),
              ),
            if (user.permissions.updateAssignedLoads)
              _HomeActionCard(
                icon: Icons.route_rounded,
                title: 'My assigned deliveries',
                subtitle: 'Update pickup, transit, issues, and delivery',
                onTap: () => _open(context, DriverLoadsPage(user: user)),
              ),
            if (user.permissions.manageClients)
              _HomeActionCard(
                icon: Icons.business_rounded,
                title: 'Clients',
                subtitle: 'Maintain customer contact information',
                onTap: () => _open(context, const ClientsPage()),
              ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invoice migration is intentionally excluded from this '
                        'foundation milestone. Existing prototype data remains '
                        'untouched while the secure delivery workflow is tested.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

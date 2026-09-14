import 'package:flutter/material.dart';
import '../services/operations.dart';
import 'records.dart';
import 'company_settings.dart';
import '../models/app_user.dart';
import 'loads/load_management_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.store, this.onSignOut, this.user});
  final AppUser? user;
  final Operations? store;
  final VoidCallback? onSignOut;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final store = widget.store ?? Operations();
  int selected = 0;
  static const labels = [
    'Overview',
    'Billing jobs',
    'Clients',
    'Invoices',
    'Expenses',
  ];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.local_shipping_outlined,
    Icons.people_outline,
    Icons.receipt_long_outlined,
    Icons.account_balance_wallet_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping),
            SizedBox(width: 12),
            Text(
              'LOBOS',
              style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 12),
            Text('TRUCKING', style: TextStyle(fontSize: 12, letterSpacing: 2)),
          ],
        ),
        actions: [
          if (widget.user != null)
            IconButton(
              tooltip: 'Driver dispatch',
              icon: const Icon(Icons.route),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoadManagementPage(user: widget.user!),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Company & invoice details',
            onPressed: () => openCompanySettings(context, store),
            icon: const Icon(Icons.settings_outlined),
          ),
          if (widget.onSignOut != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: true,
              minExtendedWidth: 210,
              selectedIndex: selected,
              onDestinationSelected: (i) => setState(() => selected = i),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icons[i]),
                    label: Text(labels[i]),
                  ),
              ],
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(
            child: selected == 0
                ? Column(
                    children: [
                      if (widget.user != null)
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: ListTile(
                            leading: const Icon(Icons.route),
                            title: const Text('Driver dispatch'),
                            subtitle: const Text(
                              'Assign loads, review progress and delivery signatures',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LoadManagementPage(user: widget.user!),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Overview(
                          store: store,
                          navigate: (i) => setState(() => selected = i),
                        ),
                      ),
                    ],
                  )
                : RecordsPage(
                    key: ValueKey(selected),
                    collection: [
                      'jobs',
                      'clients',
                      'invoices',
                      'expenses',
                    ][selected - 1],
                    store: store,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => setState(() => selected = i),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }
}

class Overview extends StatefulWidget {
  const Overview({super.key, required this.store, required this.navigate});
  final Operations store;
  final ValueChanged<int> navigate;
  @override
  State<Overview> createState() => _OverviewState();
}

class _OverviewState extends State<Overview> {
  late final jobs = widget.store.watch('jobs');
  late final invoices = widget.store.watch('invoices');
  late final expenses = widget.store.watch('expenses');
  Widget metric(
    String label,
    String value,
    String detail,
    IconData icon,
    int page,
  ) => Card(
    child: InkWell(
      onTap: () => widget.navigate(page),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Record>>(
    stream: jobs,
    builder: (context, j) => StreamBuilder<List<Record>>(
      stream: invoices,
      builder: (context, i) => StreamBuilder<List<Record>>(
        stream: expenses,
        builder: (context, e) {
          if (j.hasError || i.hasError || e.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load your overview. Check your connection and Firestore access permissions.',
                ),
              ),
            );
          }
          if (!j.hasData || !i.hasData || !e.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final active = j.data!.where((r) => r['archived'] != true).toList();
          final open =
              active
                  .where(
                    (r) =>
                        r['status'] == 'pending' ||
                        r['status'] == 'in progress',
                  )
                  .toList()
                ..sort(
                  (a, b) => (dateOf(a['scheduledDate']) ?? DateTime(2200))
                      .compareTo(dateOf(b['scheduledDate']) ?? DateTime(2200)),
                );
          final ready = active
              .where(
                (r) =>
                    r['status'] == 'completed' &&
                    r['invoiceId'] == null &&
                    !i.data!.any((inv) => inv['jobId'] == r['id']),
              )
              .length;
          final outstanding = i.data!.fold<double>(
            0,
            (s, r) => s + balanceOf(r),
          );
          final collected = i.data!.fold<double>(
            0,
            (s, r) => s + paidAmount(r),
          );
          final costs = e.data!
              .where((r) => r['archived'] != true)
              .fold<double>(0, (s, r) => s + number(r['amount']));
          final overdue = i.data!
              .where((r) => invoiceStatus(r) == 'overdue')
              .length;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF142E35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR OPERATIONS, AT A GLANCE',
                      style: TextStyle(
                        color: Color(0xFF91CDC2),
                        letterSpacing: 2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Keep the day moving.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${open.length} active jobs · $ready ready to invoice · $overdue overdue invoices',
                      style: const TextStyle(color: Color(0xFFD6E6E3)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => widget.navigate(1),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Open dispatch board'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth > 1000
                      ? 4
                      : box.maxWidth > 580
                      ? 2
                      : 1;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final card in [
                        metric(
                          'Active jobs',
                          '${open.length}',
                          '$ready completed, awaiting billing',
                          Icons.local_shipping_outlined,
                          1,
                        ),
                        metric(
                          'Outstanding',
                          money(outstanding),
                          '$overdue overdue invoices',
                          Icons.receipt_long_outlined,
                          3,
                        ),
                        metric(
                          'Collected',
                          money(collected),
                          'All-time payments received',
                          Icons.payments_outlined,
                          3,
                        ),
                        metric(
                          'Expenses',
                          money(costs),
                          'All-time active expense records',
                          Icons.account_balance_wallet_outlined,
                          4,
                        ),
                      ])
                        SizedBox(
                          width: (box.maxWidth - 12 * (columns - 1)) / columns,
                          child: card,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                'Needs attention',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (ready == 0 && overdue == 0)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Billing is caught up'),
                    subtitle: Text(
                      'No completed jobs awaiting invoices or overdue balances.',
                    ),
                  ),
                ),
              if (ready > 0)
                Card(
                  child: ListTile(
                    onTap: () => widget.navigate(1),
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text('$ready completed jobs ready to invoice'),
                    trailing: const Icon(Icons.arrow_forward),
                  ),
                ),
              if (overdue > 0)
                Card(
                  child: ListTile(
                    onTap: () => widget.navigate(3),
                    leading: const Icon(Icons.schedule),
                    title: Text('$overdue invoices past their due date'),
                    trailing: const Icon(Icons.arrow_forward),
                  ),
                ),
              const SizedBox(height: 28),
              Text(
                'Upcoming & in progress',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (open.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.local_shipping_outlined),
                    title: Text('Your dispatch board is clear'),
                    subtitle: Text(
                      'Add a client and schedule your first job to get started.',
                    ),
                  ),
                ),
              for (final row in open.take(6))
                Card(
                  child: ListTile(
                    onTap: () => widget.navigate(1),
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(
                      '${row['clientName'] ?? ''} · ${shortDate(row['scheduledDate'])}',
                    ),
                    subtitle: Text('${row['pickup']} → ${row['dropoff']}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

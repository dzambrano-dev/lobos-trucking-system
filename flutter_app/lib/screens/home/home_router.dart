import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../auth/access_pending_page.dart';
import '../driver/driver_loads_page.dart';
import 'manager_home_page.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    if (user.canUseManagerHome) {
      return ManagerHomePage(user: user);
    }
    if (user.permissions.updateAssignedLoads) {
      return DriverLoadsPage(user: user);
    }

    return const AccessPendingPage(
      title: 'No permissions assigned',
      message:
          'Your account is active, but an administrator has not assigned '
          'any Lobos Trucking permissions yet.',
    );
  }
}

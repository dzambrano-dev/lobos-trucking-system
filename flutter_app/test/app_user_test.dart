import 'package:flutter_test/flutter_test.dart';
import 'package:lobos_trucking/models/app_user.dart';

void main() {
  test('missing permissions default to denied', () {
    final user = AppUser.fromMap('driver-1', {
      'displayName': 'Driver One',
      'email': 'driver@example.com',
      'active': true,
    });

    expect(user.permissions.manageUsers, isFalse);
    expect(user.permissions.manageClients, isFalse);
    expect(user.permissions.manageLoads, isFalse);
    expect(user.permissions.viewAllLoads, isFalse);
    expect(user.permissions.updateAssignedLoads, isFalse);
  });

  test('manager home is selected from capabilities instead of a role name', () {
    const user = AppUser(
      uid: 'dispatcher-1',
      displayName: 'Dispatcher',
      email: 'dispatcher@example.com',
      active: true,
      permissions: UserPermissions(
        manageUsers: false,
        manageClients: false,
        manageLoads: true,
        viewAllLoads: false,
        updateAssignedLoads: false,
      ),
    );

    expect(user.canUseManagerHome, isTrue);
  });
}

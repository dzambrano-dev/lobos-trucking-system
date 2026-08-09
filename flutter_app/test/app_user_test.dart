import 'package:flutter_test/flutter_test.dart';
import 'package:lobos_trucking/models/app_user.dart';

void main() {
  test('complete profile is parsed without changing rule-bound values', () {
    final user = AppUser.fromMap('driver-1', {
      'displayName': 'Driver One',
      'email': 'driver@example.com',
      'active': true,
      'permissions': {
        'manageUsers': false,
        'manageClients': false,
        'manageLoads': false,
        'viewAllLoads': false,
        'updateAssignedLoads': true,
      },
    });

    expect(user.displayName, 'Driver One');
    expect(user.email, 'driver@example.com');
    expect(user.permissions.manageUsers, isFalse);
    expect(user.permissions.manageClients, isFalse);
    expect(user.permissions.manageLoads, isFalse);
    expect(user.permissions.viewAllLoads, isFalse);
    expect(user.permissions.updateAssignedLoads, isTrue);
  });

  test('missing displayName is reported instead of falling back to email', () {
    expect(
      () => AppUser.fromMap('manager-1', {
        'email': 'manager@example.com',
        'active': true,
        'permissions': _managerPermissions,
      }),
      throwsA(isA<InvalidUserProfileException>()),
    );
  });

  test('missing permissions are reported instead of silently denied', () {
    expect(
      () => AppUser.fromMap('driver-1', {
        'displayName': 'Driver One',
        'email': 'driver@example.com',
        'active': true,
      }),
      throwsA(isA<InvalidUserProfileException>()),
    );
  });

  test('displayName cannot contain invisible spaces or wrapping quotes', () {
    for (final displayName in [' Administrator ', '"Administrator"']) {
      expect(
        () => AppUser.fromMap('manager-1', {
          'displayName': displayName,
          'email': 'manager@example.com',
          'active': true,
          'permissions': _managerPermissions,
        }),
        throwsA(isA<InvalidUserProfileException>()),
      );
    }
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

const _managerPermissions = {
  'manageUsers': true,
  'manageClients': true,
  'manageLoads': true,
  'viewAllLoads': true,
  'updateAssignedLoads': true,
};

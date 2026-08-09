class UserPermissions {
  const UserPermissions({
    required this.manageUsers,
    required this.manageClients,
    required this.manageLoads,
    required this.viewAllLoads,
    required this.updateAssignedLoads,
  });

  final bool manageUsers;
  final bool manageClients;
  final bool manageLoads;
  final bool viewAllLoads;
  final bool updateAssignedLoads;

  factory UserPermissions.fromMap(Map<String, dynamic> data) {
    return UserPermissions(
      manageUsers: data['manageUsers'] as bool,
      manageClients: data['manageClients'] as bool,
      manageLoads: data['manageLoads'] as bool,
      viewAllLoads: data['viewAllLoads'] as bool,
      updateAssignedLoads: data['updateAssignedLoads'] as bool,
    );
  }

  Map<String, bool> toMap() {
    return {
      'manageUsers': manageUsers,
      'manageClients': manageClients,
      'manageLoads': manageLoads,
      'viewAllLoads': viewAllLoads,
      'updateAssignedLoads': updateAssignedLoads,
    };
  }
}

class InvalidUserProfileException implements Exception {
  const InvalidUserProfileException({required this.uid, required this.reason});

  final String uid;
  final String reason;

  @override
  String toString() => 'Invalid user profile users/$uid: $reason';
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.active,
    required this.permissions,
  });

  final String uid;
  final String displayName;
  final String email;
  final bool active;
  final UserPermissions permissions;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    const requiredFields = {'displayName', 'email', 'active', 'permissions'};
    const permissionFields = {
      'manageUsers',
      'manageClients',
      'manageLoads',
      'viewAllLoads',
      'updateAssignedLoads',
    };

    Never invalid(String reason) {
      throw InvalidUserProfileException(uid: uid, reason: reason);
    }

    final profileFields = data.keys.toSet();
    final missingFields = requiredFields.difference(profileFields);
    if (missingFields.isNotEmpty) {
      invalid('missing ${_fieldList(missingFields)}.');
    }
    final unsupportedFields = profileFields.difference(requiredFields);
    if (unsupportedFields.isNotEmpty) {
      invalid('remove unsupported ${_fieldList(unsupportedFields)}.');
    }

    final rawDisplayName = data['displayName'];
    if (rawDisplayName is! String) {
      invalid('displayName must be a string.');
    }
    final displayName = rawDisplayName.trim();
    if (displayName.isEmpty || displayName.length > 120) {
      invalid('displayName must contain 1 to 120 characters.');
    }
    if (displayName != rawDisplayName) {
      invalid('remove spaces before or after displayName.');
    }
    if (_hasWrappingQuotes(displayName)) {
      invalid('remove the quotation marks surrounding displayName.');
    }

    final rawEmail = data['email'];
    if (rawEmail is! String) {
      invalid('email must be a string.');
    }
    final email = rawEmail.trim();
    if (email.length < 4 || email.length > 254) {
      invalid('email must contain 4 to 254 characters.');
    }
    if (email != rawEmail) {
      invalid('remove spaces before or after email.');
    }
    if (_hasWrappingQuotes(email)) {
      invalid('remove the quotation marks surrounding email.');
    }

    if (data['active'] is! bool) {
      invalid('active must be a boolean.');
    }

    final rawPermissions = data['permissions'];
    if (rawPermissions is! Map<String, dynamic>) {
      invalid('permissions must be a map.');
    }
    final permissionsFields = rawPermissions.keys.toSet();
    final missingPermissions = permissionFields.difference(permissionsFields);
    if (missingPermissions.isNotEmpty) {
      invalid('permissions is missing ${_fieldList(missingPermissions)}.');
    }
    final unsupportedPermissions = permissionsFields.difference(
      permissionFields,
    );
    if (unsupportedPermissions.isNotEmpty) {
      invalid(
        'remove unsupported permissions '
        '${_fieldList(unsupportedPermissions)}.',
      );
    }
    for (final field in permissionFields) {
      if (rawPermissions[field] is! bool) {
        invalid('permissions.$field must be a boolean.');
      }
    }

    return AppUser(
      uid: uid,
      displayName: displayName,
      email: email,
      active: data['active'] as bool,
      permissions: UserPermissions.fromMap(rawPermissions),
    );
  }

  bool get canUseManagerHome =>
      permissions.manageLoads ||
      permissions.manageClients ||
      permissions.viewAllLoads;
}

String _fieldList(Iterable<String> fields) {
  final sorted = fields.toList()..sort();
  return sorted.join(', ');
}

bool _hasWrappingQuotes(String value) {
  if (value.length < 2) return false;
  return (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"));
}

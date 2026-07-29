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

  factory UserPermissions.fromMap(Map<String, dynamic>? data) {
    return UserPermissions(
      manageUsers: data?['manageUsers'] == true,
      manageClients: data?['manageClients'] == true,
      manageLoads: data?['manageLoads'] == true,
      viewAllLoads: data?['viewAllLoads'] == true,
      updateAssignedLoads: data?['updateAssignedLoads'] == true,
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
    return AppUser(
      uid: uid,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : (data['email'] as String? ?? 'Team member'),
      email: data['email'] as String? ?? '',
      active: data['active'] == true,
      permissions: UserPermissions.fromMap(
        data['permissions'] as Map<String, dynamic>?,
      ),
    );
  }

  bool get canUseManagerHome =>
      permissions.manageLoads ||
      permissions.manageClients ||
      permissions.viewAllLoads;
}

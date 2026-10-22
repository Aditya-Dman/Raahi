import 'user_session.dart' as user_session;

enum RaahiRole {
  tourist,
  emergencyResponder,
  policeOfficer,
  tourismOfficer,
  administrator,
}

class RoleAccess {
  static RaahiRole currentRole() {
    final raw =
        user_session.UserSession.getCurrentUser()?.userType ?? 'Tourist';
    return switch (raw.toLowerCase()) {
      'emergency responder' => RaahiRole.emergencyResponder,
      'police officer' => RaahiRole.policeOfficer,
      'tourism officer' => RaahiRole.tourismOfficer,
      'administrator' => RaahiRole.administrator,
      _ => RaahiRole.tourist,
    };
  }

  static String label(RaahiRole role) => switch (role) {
    RaahiRole.tourist => 'Tourist',
    RaahiRole.emergencyResponder => 'Emergency Responder',
    RaahiRole.policeOfficer => 'Police Officer',
    RaahiRole.tourismOfficer => 'Tourism Officer',
    RaahiRole.administrator => 'Administrator',
  };

  static String description(RaahiRole role) => switch (role) {
    RaahiRole.tourist => 'Personal safety tools and your own safety data.',
    RaahiRole.emergencyResponder =>
      'Assigned emergency alerts and response history.',
    RaahiRole.policeOfficer =>
      'Authorized security incidents and alert history.',
    RaahiRole.tourismOfficer =>
      'Tourism safety trends and aggregate information.',
    RaahiRole.administrator =>
      'System management and authorized safety records.',
  };

  static bool canViewOperationalHistory(RaahiRole role) =>
      role != RaahiRole.tourist;

  static bool canManageUsers(RaahiRole role) => role == RaahiRole.administrator;

  static bool canReviewAssignedAlerts(RaahiRole role) =>
      role == RaahiRole.emergencyResponder || role == RaahiRole.policeOfficer;
}

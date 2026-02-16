enum UserRole { admin, readOnly }

class UserRoleService {
  static const Set<String> adminEmails = {
    "wpenfold@bigpond.net.au",
    "paulfruin30@gmail.com",
  };

  UserRole role = UserRole.readOnly;

  bool get isAdmin => role == UserRole.admin;
  bool get isReadOnly => role == UserRole.readOnly;

  void setUser(String email) {
    final normalized = email.trim().toLowerCase();

    if (adminEmails.contains(normalized)) {
      role = UserRole.admin;
    } else {
      role = UserRole.readOnly;
    }
  }
}
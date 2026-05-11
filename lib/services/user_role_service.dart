enum UserRole { admin, readOnly }

class UserRoleService {
  static const Set<String> adminEmails = {
    "wpenfold@bigpond.net.au",
    "paulfruin30@gmail.com",
    "wayne.penfold@gmail.com",
    "wayneliz7@outlook.com",
    "chrisoakenfall@gmail.com",
    "matty_hyatt@hotmail.com",
     };

  String? _currentUser;
  UserRole role = UserRole.readOnly;

  String? get currentUser => _currentUser;

  bool get isAdmin => role == UserRole.admin;
  bool get isReadOnly => role == UserRole.readOnly;

  void setUser(String email) {
    final normalized = email.trim().toLowerCase();
    _currentUser = normalized;

    if (adminEmails.contains(normalized)) {
      role = UserRole.admin;
    } else {
      role = UserRole.readOnly;
    }

    print("UserRoleService → user: $_currentUser, role: $role");
  }
}
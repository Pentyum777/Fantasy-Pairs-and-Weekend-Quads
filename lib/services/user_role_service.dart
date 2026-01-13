enum UserRole { admin, readOnly }

class UserRoleService {
  UserRole role = UserRole.readOnly;

  bool get isAdmin => role == UserRole.admin;
  bool get isReadOnly => role == UserRole.readOnly;

  void setRole(UserRole newRole) {
    role = newRole;
  }
}
class MsalAccount {
  final String username;
  MsalAccount(this.username);
}

class MsalService {
  static void listenForToken(
    void Function(String token, MsalAccount account) onTokenReceived,
  ) {
    // No-op on Windows, Android, iOS, macOS, Linux
  }

  static void startLogin(List<String> scopes) {}
  static void startGetToken(List<String> scopes) {}
}
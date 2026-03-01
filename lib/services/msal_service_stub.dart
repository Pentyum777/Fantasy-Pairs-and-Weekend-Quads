class MsalAccount {
  final String username;
  MsalAccount(this.username);
}

class MsalService {
  static void listenForToken(
    void Function(String token, MsalAccount account) onTokenReceived,
  ) {
    // No-op on non-web platforms
  }

  static void startLogin(List<String> scopes) {}
  static void startGetToken(List<String> scopes) {}
}
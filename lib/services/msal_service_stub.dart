class MsalAccount {
  final String username;
  MsalAccount(this.username);
}

class MsalService {
  static void listenForToken(void Function(String, MsalAccount) _) {}
  static void startLogin(List<String> scopes) {}
  static void startGetToken(List<String> scopes) {}
}
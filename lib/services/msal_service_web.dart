import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:js' as js;

class MsalAccount {
  final String username;

  MsalAccount(this.username);

  factory MsalAccount.fromJsObject(dynamic obj) {
    if (obj == null) return MsalAccount("unknown");
    try {
      return MsalAccount(obj["username"] ?? "unknown");
    } catch (_) {
      return MsalAccount("unknown");
    }
  }
}

class MsalService {
  /// Listen for token + account via JS callback
  static void listenForToken(
    void Function(String token, MsalAccount account) onTokenReceived,
  ) {
    print("MSAL(Dart): Registering onMsalToken callback");

    // JS → Dart callback
    js.context['onMsalToken'] = (token, accountObj) {
      print("MSAL(Dart): Token received from JS → $token");

      if (token is! String) {
        print("MSAL(Dart): ERROR — token was not a string: $token");
        return;
      }

      final account = MsalAccount.fromJsObject(accountObj);
      onTokenReceived(token, account);
    };

    // Check for pending token (page reload scenario)
    final pendingToken = js.context['__pendingMsalToken'];
    final pendingAccount = js.context['__pendingMsalAccount'];

    if (pendingToken != null && pendingToken is String) {
      print("MSAL(Dart): Found pending token → delivering immediately");

      final account = MsalAccount.fromJsObject(pendingAccount);
      onTokenReceived(pendingToken, account);

      js.context['__pendingMsalToken'] = null;
      js.context['__pendingMsalAccount'] = null;
    }
  }

  /// Trigger login in JS
  static void startLogin(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    print("MSAL(Dart): startLogin with $scopesJson");
    js.context.callMethod('msalLogin', [scopesJson]);
  }

  /// Optional: silent token acquisition
  static void startGetToken(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    print("MSAL(Dart): startGetToken with $scopesJson");
    js.context.callMethod('msalGetToken', [scopesJson]);
  }
}
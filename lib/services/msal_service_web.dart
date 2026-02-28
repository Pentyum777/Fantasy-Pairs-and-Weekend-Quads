import 'dart:convert';
import 'dart:js_util' as js_util;
import 'package:js/js_util.dart' show allowInterop;

class MsalAccount {
  final String username;

  MsalAccount(this.username);

  factory MsalAccount.fromJsObject(dynamic obj) {
    if (obj == null) return MsalAccount("unknown");
    try {
      return MsalAccount(js_util.getProperty(obj, "username") ?? "unknown");
    } catch (_) {
      return MsalAccount("unknown");
    }
  }
}

class MsalService {
  static void listenForToken(
    void Function(String token, MsalAccount account) onTokenReceived,
  ) {
    print("MSAL(Dart): Registering onMsalToken callback");

    // JS → Dart callback MUST use allowInterop
    js_util.setProperty(
      js_util.globalThis,
      'onMsalToken',
      allowInterop((token, accountObj) {
        print("MSAL(Dart): Token received from JS → $token");

        if (token is! String) {
          print("MSAL(Dart): ERROR — token was not a string: $token");
          return;
        }

        final account = MsalAccount.fromJsObject(accountObj);
        onTokenReceived(token, account);
      }),
    );

    // Handle pending token (page reload scenario)
    final pendingToken =
        js_util.getProperty(js_util.globalThis, '__pendingMsalToken');
    final pendingAccount =
        js_util.getProperty(js_util.globalThis, '__pendingMsalAccount');

    if (pendingToken != null && pendingToken is String) {
      print("MSAL(Dart): Found pending token → delivering immediately");

      final account = MsalAccount.fromJsObject(pendingAccount);
      onTokenReceived(pendingToken, account);

      js_util.setProperty(js_util.globalThis, '__pendingMsalToken', null);
      js_util.setProperty(js_util.globalThis, '__pendingMsalAccount', null);
    }
  }

  static void startLogin(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    print("MSAL(Dart): startLogin with $scopesJson");

    js_util.callMethod(js_util.globalThis, 'msalLogin', [scopesJson]);
  }

  static void startGetToken(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    print("MSAL(Dart): startGetToken with $scopesJson");

    js_util.callMethod(js_util.globalThis, 'msalGetToken', [scopesJson]);
  }
}
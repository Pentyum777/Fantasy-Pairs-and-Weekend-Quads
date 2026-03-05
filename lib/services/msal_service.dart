import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

//
// WEB IMPLEMENTATION
//
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:js/js.dart';

@JS()
@anonymous
class JsMsalAccount {
  external String? get username;
}

class MsalAccount {
  final String username;
  MsalAccount(this.username);

  factory MsalAccount.fromJsObject(JsMsalAccount? obj) {
    return MsalAccount(obj?.username ?? "unknown");
  }
}

//
// UNIFIED SERVICE
//
class MsalService {
  //
  // WEB IMPLEMENTATION
  //
  static void listenForToken(
    void Function(String token, MsalAccount account) onTokenReceived,
  ) {
    if (!kIsWeb) return; // Windows/Android/iOS → no-op

    final html.Window global = html.window;

    js_util.setProperty(
      global,
      'onMsalToken',
      allowInterop((dynamic token, dynamic accountObj) {
        final tokenStr = token as String?;
        if (tokenStr == null) return;

        final account = MsalAccount.fromJsObject(accountObj as JsMsalAccount?);
        onTokenReceived(tokenStr, account);
      }),
    );

    final pendingToken = js_util.getProperty(global, '__pendingMsalToken');
    final pendingAccount = js_util.getProperty(global, '__pendingMsalAccount');

    if (pendingToken != null && pendingToken is String) {
      final account =
          MsalAccount.fromJsObject(pendingAccount as JsMsalAccount?);

      onTokenReceived(pendingToken, account);

      js_util.setProperty(global, '__pendingMsalToken', null);
      js_util.setProperty(global, '__pendingMsalAccount', null);
    }
  }

  static void startLogin(List<String> scopes) {
    if (!kIsWeb) return; // Windows/Android/iOS → no-op

    final scopesJson = jsonEncode(scopes);
    js_util.callMethod(html.window, 'msalLogin', [scopesJson]);
  }

  static void startGetToken(List<String> scopes) {
    if (!kIsWeb) return; // Windows/Android/iOS → no-op

    final scopesJson = jsonEncode(scopes);
    js_util.callMethod(html.window, 'msalGetToken', [scopesJson]);
  }
}

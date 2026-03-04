@JS()
library msal_service_web;

import 'dart:convert';
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

class MsalService {
  static html.Window get _global => html.window;

  static void listenForToken(
    void Function(String token, MsalAccount account) onTokenReceived,
  ) {
    js_util.setProperty(
      _global,
      'onMsalToken',
      allowInterop((dynamic token, dynamic accountObj) {
        final tokenStr = token as String?;
        if (tokenStr == null) return;

        final account = MsalAccount.fromJsObject(accountObj as JsMsalAccount?);
        onTokenReceived(tokenStr, account);
      }),
    );

    final pendingToken = js_util.getProperty(_global, '__pendingMsalToken');
    final pendingAccount = js_util.getProperty(_global, '__pendingMsalAccount');

    if (pendingToken != null && pendingToken is String) {
      final tokenStr = pendingToken;
      final account =
          MsalAccount.fromJsObject(pendingAccount as JsMsalAccount?);

      onTokenReceived(tokenStr, account);

      js_util.setProperty(_global, '__pendingMsalToken', null);
      js_util.setProperty(_global, '__pendingMsalAccount', null);
    }
  }

  static void startLogin(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    js_util.callMethod(_global, 'msalLogin', [scopesJson]);
  }

  static void startGetToken(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    js_util.callMethod(_global, 'msalGetToken', [scopesJson]);
  }
}
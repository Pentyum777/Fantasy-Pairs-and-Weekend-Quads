@JS()
library msal_service_web;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS()
@staticInterop
class JsMsalAccount {}

extension JsMsalAccountExt on JsMsalAccount {
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
  static void listenForToken(
    void Function(String token, MsalAccount account) onTokenReceived,
  ) {
    // Register callback on window
    globalThis.setProperty(
      'onMsalToken'.toJS,
      ((JSAny token, JSAny accountObj) {
        final tokenStr = token.dartify() as String?;
        if (tokenStr == null) return;

        final account = MsalAccount.fromJsObject(accountObj as JsMsalAccount?);
        onTokenReceived(tokenStr, account);
      }).toJS,
    );

    // Handle pending token
    final pendingToken = globalThis.getProperty('__pendingMsalToken'.toJS);
    final pendingAccount = globalThis.getProperty('__pendingMsalAccount'.toJS);

    if (pendingToken != null && pendingToken is JSString) {
      final tokenStr = pendingToken.dartify() as String;
      final account =
          MsalAccount.fromJsObject(pendingAccount as JsMsalAccount?);

      onTokenReceived(tokenStr, account);

      globalThis.setProperty('__pendingMsalToken'.toJS, null.toJS);
      globalThis.setProperty('__pendingMsalAccount'.toJS, null.toJS);
    }
  }

  static void startLogin(List<String> scopes) {
    final scopesJson = jsonEncode(scopes).toJS;
    globalThis.callMethod('msalLogin'.toJS, [scopesJson]);
  }

  static void startGetToken(List<String> scopes) {
    final scopesJson = jsonEncode(scopes).toJS;
    globalThis.callMethod('msalGetToken'.toJS, [scopesJson]);
  }
}
import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:html' as html;
// ignore: deprecated_member_use
import 'dart:js' as js;

class MsalService {
  /// Listen for the msalToken event dispatched from msal.js
  static void listenForToken(void Function(String token) onTokenReceived) {
    html.window.addEventListener('msalToken', (event) {
      final custom = event as html.CustomEvent;
      final detail = custom.detail;

      if (detail is String) {
        onTokenReceived(detail);
      } else {
        print("MSAL(Dart): msalToken event received with non-string detail: $detail");
      }
    });
  }

  /// Trigger login in JS; token will come back via the msalToken event.
  static void startLogin(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    print("MSAL(Dart): startLogin with $scopesJson");
    js.context.callMethod('msalLogin', [scopesJson]);
  }

  /// Optional: trigger getToken (silent → popup) from Dart.
  static void startGetToken(List<String> scopes) {
    final scopesJson = jsonEncode(scopes);
    print("MSAL(Dart): startGetToken with $scopesJson");
    js.context.callMethod('msalGetToken', [scopesJson]);
  }
}
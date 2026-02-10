import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:js' as js;

class MsalService {
  /// Listen for token via JS callback (no DOM events)
  static void listenForToken(void Function(String token) onTokenReceived) {
    print("MSAL(Dart): Registering onMsalToken callback");

    // Register callback for JS → Dart token delivery
    js.context['onMsalToken'] = (token) {
      print("MSAL(Dart): Token received from JS → $token");

      if (token is String) {
        onTokenReceived(token);
      } else {
        print("MSAL(Dart): ERROR — token was not a string: $token");
      }
    };

    // Check for pending token
    final pending = js.context['__pendingMsalToken'];
    if (pending != null && pending is String) {
      print("MSAL(Dart): Found pending token → delivering immediately");
      onTokenReceived(pending);
      js.context['__pendingMsalToken'] = null;
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
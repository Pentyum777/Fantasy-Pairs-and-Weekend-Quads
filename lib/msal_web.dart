// This file is ONLY used on Flutter Web.
// It provides MSAL.js authentication via JavaScript interop.

import 'dart:async';
import 'dart:js';

late JsObject msalInstance;

/// MUST be called once at app startup
void initMsal() {
  final msalConfig = JsObject.jsify({
    'auth': {
      'clientId': '28dcac5c-ef2d-4dd8-a724-d0a6ef0e0523',
      'redirectUri': 'http://localhost:57777',
    }
  });

  msalInstance =
      JsObject(context['msal']['PublicClientApplication'], [msalConfig]);
}

Future<String?> acquireTokenWithMsal(List<String> scopes) async {
  try {
    final request = JsObject.jsify({
      'scopes': scopes,
      'clientId': '28dcac5c-ef2d-4dd8-a724-d0a6ef0e0523',
    });

    // Try silent login first
    try {
      final silentPromise =
          msalInstance.callMethod('acquireTokenSilent', [request]);

      final silentResult = await _promiseToFuture(silentPromise);

      return silentResult['accessToken'];
    } catch (_) {
      // Silent failed — continue to popup
    }

    // Popup login
    final loginPromise =
        msalInstance.callMethod('loginPopup', [request]);

    final loginResult = await _promiseToFuture(loginPromise);

    // Set active account
    final account = loginResult['account'];
    if (account != null) {
      msalInstance.callMethod('setActiveAccount', [account]);
    }

    // Acquire token
    final tokenPromise =
        msalInstance.callMethod('acquireTokenPopup', [request]);

    final tokenResult = await _promiseToFuture(tokenPromise);

    return tokenResult['accessToken'];
  } catch (e) {
    print("MSAL Web Error: $e");
    return null;
  }
}

/// Converts a JS Promise into a Dart Future (compatible with all Flutter Web SDKs)
Future<dynamic> _promiseToFuture(dynamic jsPromise) {
  final completer = Completer<dynamic>();

  jsPromise.callMethod('then', [
    (result) => completer.complete(result),
  ]);

  jsPromise.callMethod('catch', [
    (error) => completer.completeError(error),
  ]);

  return completer.future;
}